# PowerShell script to force delete AWS resources that are causing issues

Write-Host "ELI5 Twitter Bot - Force Delete Resources (PowerShell)"
Write-Host "===================================================="
Write-Host ""
Write-Host "This script will force delete AWS resources that are causing issues."
Write-Host "WARNING: This will permanently delete resources. Make sure you understand the implications."
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

# Function to force delete a secret
function Force-DeleteSecret {
    param (
        [string]$secretName
    )
    
    Write-Host "Attempting to force delete secret $secretName..."
    
    try {
        # Check if the secret exists
        $secretInfo = aws secretsmanager describe-secret --secret-id $secretName --region $awsRegion 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            # Secret exists, check if it's already scheduled for deletion
            $secretJson = $secretInfo | ConvertFrom-Json
            
            if ($secretJson.DeletedDate) {
                Write-Host "Secret $secretName is already scheduled for deletion. Forcing immediate deletion..."
                
                # Force delete the secret (no recovery window)
                aws secretsmanager delete-secret --secret-id $secretName --force-delete-without-recovery --region $awsRegion
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Secret $secretName has been force deleted."
                    return $true
                } else {
                    Write-Host "Failed to force delete secret $secretName."
                    return $false
                }
            } else {
                Write-Host "Secret $secretName exists but is not scheduled for deletion. Deleting with no recovery window..."
                
                # Delete the secret with no recovery window
                aws secretsmanager delete-secret --secret-id $secretName --force-delete-without-recovery --region $awsRegion
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Secret $secretName has been deleted with no recovery window."
                    return $true
                } else {
                    Write-Host "Failed to delete secret $secretName."
                    return $false
                }
            }
        } else {
            Write-Host "Secret $secretName does not exist or cannot be accessed."
            return $true  # Consider it a success if the secret doesn't exist
        }
    } catch {
        Write-Host "Error while trying to delete secret $secretName."
        Write-Host $_.Exception.Message
        return $false
    }
}

# Function to force delete an ECR repository
function Force-DeleteECRRepository {
    param (
        [string]$repositoryName
    )
    
    Write-Host "Attempting to force delete ECR repository $repositoryName..."
    
    try {
        # Check if the repository exists
        $repoInfo = aws ecr describe-repositories --repository-names $repositoryName --region $awsRegion 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            # Repository exists, delete all images first
            Write-Host "ECR repository $repositoryName exists. Deleting all images first..."
            
            # Get all image digests
            $imageIds = aws ecr list-images --repository-name $repositoryName --region $awsRegion --query 'imageIds[*]' --output json
            
            if ($LASTEXITCODE -eq 0 -and $imageIds -ne "[]") {
                # Delete all images
                Write-Host "Deleting all images in repository $repositoryName..."
                aws ecr batch-delete-image --repository-name $repositoryName --image-ids "$imageIds" --region $awsRegion
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "Failed to delete images in repository $repositoryName."
                }
            } else {
                Write-Host "No images found in repository $repositoryName or failed to list images."
            }
            
            # Delete the repository
            Write-Host "Deleting ECR repository $repositoryName..."
            aws ecr delete-repository --repository-name $repositoryName --force --region $awsRegion
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "ECR repository $repositoryName has been deleted."
                return $true
            } else {
                Write-Host "Failed to delete ECR repository $repositoryName."
                return $false
            }
        } else {
            Write-Host "ECR repository $repositoryName does not exist or cannot be accessed."
            return $true  # Consider it a success if the repository doesn't exist
        }
    } catch {
        Write-Host "Error while trying to delete ECR repository $repositoryName."
        Write-Host $_.Exception.Message
        return $false
    }
}

# Define resource names
$twitterSecretName = "eli5-twitter-bot/twitter-credentials-dev"
$openaiSecretName = "eli5-twitter-bot/openai-credentials-dev"
$ecrRepositoryName = "eli5-twitter-bot-dev"

# Ask for confirmation
Write-Host ""
Write-Host "This script will force delete the following resources:"
Write-Host "1. Secret: $twitterSecretName"
Write-Host "2. Secret: $openaiSecretName"
Write-Host "3. ECR Repository: $ecrRepositoryName"
Write-Host ""
Write-Host "WARNING: This action cannot be undone. All data in these resources will be permanently deleted."
Write-Host ""
$confirmation = Read-Host "Are you sure you want to proceed? (y/n)"

if ($confirmation -ne "y" -and $confirmation -ne "Y") {
    Write-Host "Operation cancelled."
    exit 0
}

# Force delete secrets
$twitterSecretDeleted = Force-DeleteSecret -secretName $twitterSecretName
$openaiSecretDeleted = Force-DeleteSecret -secretName $openaiSecretName

# Force delete ECR repository
$ecrRepositoryDeleted = Force-DeleteECRRepository -repositoryName $ecrRepositoryName

# Summary
Write-Host ""
Write-Host "Force deletion summary:"
Write-Host "----------------------"
if ($twitterSecretDeleted) {
    Write-Host "Twitter Secret: Deleted"
} else {
    Write-Host "Twitter Secret: Failed"
}

if ($openaiSecretDeleted) {
    Write-Host "OpenAI Secret: Deleted"
} else {
    Write-Host "OpenAI Secret: Failed"
}

if ($ecrRepositoryDeleted) {
    Write-Host "ECR Repository: Deleted"
} else {
    Write-Host "ECR Repository: Failed"
}
Write-Host ""

if ($twitterSecretDeleted -and $openaiSecretDeleted -and $ecrRepositoryDeleted) {
    Write-Host "All resources have been successfully deleted."
    Write-Host "You can now proceed with deployment."
} else {
    Write-Host "Some resources could not be deleted. Please check the AWS Console for more information."
    Write-Host "You may need to manually delete these resources before proceeding with deployment."
}

Write-Host ""
Write-Host "Script completed."
Write-Host ""
