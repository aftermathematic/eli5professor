# PowerShell script to wait for AWS resources to be deleted

Write-Host "ELI5 Discord Bot - Wait for Resource Deletion (PowerShell)"
Write-Host "======================================================="
Write-Host ""
Write-Host "This script will wait for AWS resources to be deleted before proceeding with deployment."
Write-Host ""

# Check if AWS CLI is installed
try {
    $awsVersion = aws --version
    Write-Host "AWS CLI is installed: $awsVersion"
} catch {
    Write-Host "AWS CLI is not installed. Please install it first:"
    Write-Host "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
}

# Get AWS region
$awsRegion = aws configure get region
if ([string]::IsNullOrEmpty($awsRegion)) {
    $awsRegion = "eu-west-3"  # Default region
}
Write-Host "AWS Region: $awsRegion"

# Function to check if a secret exists and is scheduled for deletion
function Check-SecretDeletion {
    param (
        [string]$secretName
    )
    
    Write-Host "Checking if secret $secretName is scheduled for deletion..."
    
    try {
        $secretInfo = aws secretsmanager describe-secret --secret-id $secretName --region $awsRegion | ConvertFrom-Json
        
        if ($secretInfo.DeletedDate) {
            Write-Host "Secret $secretName is scheduled for deletion. Waiting for deletion to complete..."
            return $true
        } else {
            Write-Host "Secret $secretName exists but is not scheduled for deletion."
            return $false
        }
    } catch {
        Write-Host "Secret $secretName does not exist or cannot be accessed."
        return $false
    }
}

# Function to check if an ECR repository exists
function Check-ECRRepository {
    param (
        [string]$repositoryName
    )
    
    Write-Host "Checking if ECR repository $repositoryName exists..."
    
    try {
        $repoInfo = aws ecr describe-repositories --repository-names $repositoryName --region $awsRegion | ConvertFrom-Json
        
        if ($repoInfo.repositories.Count -gt 0) {
            Write-Host "ECR repository $repositoryName exists."
            return $true
        } else {
            Write-Host "ECR repository $repositoryName does not exist."
            return $false
        }
    } catch {
        Write-Host "ECR repository $repositoryName does not exist or cannot be accessed."
        return $false
    }
}

# Function to wait for a secret to be deleted
function Wait-ForSecretDeletion {
    param (
        [string]$secretName,
        [int]$timeoutSeconds = 600
    )
    
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($timeoutSeconds)
    
    while ((Get-Date) -lt $endTime) {
        try {
            $secretInfo = aws secretsmanager describe-secret --secret-id $secretName --region $awsRegion | ConvertFrom-Json
            
            if ($secretInfo.DeletedDate) {
                Write-Host "Secret $secretName is still scheduled for deletion. Waiting..."
                Start-Sleep -Seconds 30
            } else {
                Write-Host "Secret $secretName is no longer scheduled for deletion."
                return $true
            }
        } catch {
            Write-Host "Secret $secretName no longer exists or cannot be accessed. Deletion complete."
            return $true
        }
    }
    
    Write-Host "Timeout waiting for secret $secretName to be deleted."
    return $false
}

# Check for secrets scheduled for deletion
$discordSecretName = "eli5-discord-bot/discord-credentials-dev"
$openaiSecretName = "eli5-discord-bot/openai-credentials-dev"
$ecrRepositoryName = "eli5-discord-bot-dev"

$discordSecretDeleting = Check-SecretDeletion -secretName $discordSecretName
$openaiSecretDeleting = Check-SecretDeletion -secretName $openaiSecretName
$ecrRepositoryExists = Check-ECRRepository -repositoryName $ecrRepositoryName

# If any resources are scheduled for deletion, ask the user what to do
if ($discordSecretDeleting -or $openaiSecretDeleting -or $ecrRepositoryExists) {
    Write-Host ""
    Write-Host "Some resources already exist or are scheduled for deletion."
    Write-Host "You have the following options:"
    Write-Host "1. Wait for the resources to be deleted (may take up to 30 days for secrets)"
    Write-Host "2. Run the force_cleanup.sh script to clean up existing resources"
    Write-Host "3. Proceed with deployment anyway (may fail if resources still exist)"
    Write-Host ""
    $choice = Read-Host "Enter your choice (1, 2, or 3)"
    
    if ($choice -eq "1") {
        Write-Host ""
        Write-Host "Waiting for resources to be deleted..."
        
        if ($discordSecretDeleting) {
            $result = Wait-ForSecretDeletion -secretName $discordSecretName
            if (-not $result) {
                Write-Host "Failed to wait for Discord secret deletion. You may need to wait longer or use the force_cleanup.sh script."
            }
        }
        
        if ($openaiSecretDeleting) {
            $result = Wait-ForSecretDeletion -secretName $openaiSecretName
            if (-not $result) {
                Write-Host "Failed to wait for OpenAI secret deletion. You may need to wait longer or use the force_cleanup.sh script."
            }
        }
        
        Write-Host ""
        Write-Host "Resource deletion check complete."
        Write-Host "You can now proceed with deployment."
        Write-Host ""
    } elseif ($choice -eq "2") {
        Write-Host ""
        Write-Host "Running force_cleanup.sh script..."
        
        # Check if we're on Windows
        if ($env:OS -match "Windows") {
            # We're on Windows, so use WSL to run the bash script
            if (Get-Command wsl -ErrorAction SilentlyContinue) {
                wsl ./force_cleanup.sh
            } else {
                Write-Host "WSL is not available. Please run the force_cleanup.sh script manually in a bash environment."
            }
        } else {
            # We're on Linux/macOS, so run the script directly
            bash ./force_cleanup.sh
        }
        
        Write-Host ""
        Write-Host "Force cleanup complete."
        Write-Host "You can now proceed with deployment."
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "Proceeding with deployment anyway."
        Write-Host "Note that deployment may fail if resources still exist."
        Write-Host ""
        
        Write-Host "[DEBUG] Starting deployment continuation with option 3..."
        Write-Host "[DEBUG] Current directory: $(Get-Location)"
        Write-Host "[DEBUG] AWS Region: $awsRegion"
        Write-Host "[DEBUG] Discord secret deleting: $discordSecretDeleting"
        Write-Host "[DEBUG] OpenAI secret deleting: $openaiSecretDeleting"
        Write-Host "[DEBUG] ECR exists: $ecrRepositoryExists"
        Write-Host ""
        
        # Log environment variables for debugging
        Write-Host "[DEBUG] Environment variables:"
        Write-Host "[DEBUG] PATH: $env:PATH"
        Write-Host "[DEBUG] DEPLOY_ALL_RUNNING: $env:DEPLOY_ALL_RUNNING"
        Write-Host ""
        
        # Check if we're being called from deploy_all.ps1
        if ($env:DEPLOY_ALL_RUNNING) {
            Write-Host "[DEBUG] Called from deploy_all.ps1 - returning control"
            exit 0
        } else {
            Write-Host "[DEBUG] Running standalone - continuing with next steps"
            
            # Try to continue with the next deployment step
            Write-Host "[DEBUG] Attempting to continue deployment..."
            
            # Check if terraform is available
            try {
                $terraformVersion = terraform --version
                Write-Host "[DEBUG] Terraform found: $terraformVersion"
            } catch {
                Write-Host "[ERROR] Terraform not found in PATH"
                Write-Host "[DEBUG] Current PATH: $env:PATH"
                exit 1
            }
            
            # Check if we have terraform files
            if (-not (Test-Path "main.tf")) {
                Write-Host "[ERROR] main.tf not found in current directory"
                Write-Host "[DEBUG] Current directory contents:"
                Get-ChildItem | Format-Table Name
                exit 1
            } else {
                Write-Host "[DEBUG] main.tf found"
            }
            
            # Try to run terraform init
            Write-Host "[DEBUG] Running terraform init..."
            terraform init
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[ERROR] Terraform init failed with exit code $LASTEXITCODE"
                exit $LASTEXITCODE
            } else {
                Write-Host "[DEBUG] Terraform init successful"
            }
        }
    }
} else {
    Write-Host ""
    Write-Host "No resources are scheduled for deletion."
    Write-Host "You can proceed with deployment."
    Write-Host ""
}

Write-Host "Script completed."
Write-Host ""
