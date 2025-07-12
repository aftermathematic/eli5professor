# PowerShell script to fix Terraform initialization issues related to _netrc file

Write-Host "ELI5 Discord Bot - Fix Terraform Init (PowerShell)"
Write-Host "==============================================="
Write-Host ""
Write-Host "This script will fix Terraform initialization issues related to the _netrc file."
Write-Host ""

# Check if Terraform is installed
try {
    $terraformVersion = terraform --version
    Write-Host "Terraform is installed: $terraformVersion"
} catch {
    Write-Host "Terraform is not installed. Please install it first:"
    Write-Host "https://developer.hashicorp.com/terraform/downloads"
    exit 1
}

# Create the provider directory structure
$providerDir = "$env:USERPROFILE\.terraform.d\plugins\registry.terraform.io\hashicorp\aws\4.67.0\windows_amd64"
Write-Host "Creating provider directory structure..."
New-Item -ItemType Directory -Path $providerDir -Force | Out-Null
Write-Host "Provider directory: $providerDir"

# Download the AWS provider
Write-Host "Downloading AWS provider..."
$providerUrl = "https://releases.hashicorp.com/terraform-provider-aws/4.67.0/terraform-provider-aws_4.67.0_windows_amd64.zip"
$zipFile = "$env:TEMP\terraform-provider-aws.zip"
Invoke-WebRequest -Uri $providerUrl -OutFile $zipFile
Write-Host "AWS provider downloaded to $zipFile"

# Extract the AWS provider
Write-Host "Extracting AWS provider..."
Expand-Archive -Path $zipFile -DestinationPath $providerDir -Force
Write-Host "AWS provider extracted to $providerDir"

# Verify the provider file exists
$providerFile = "$providerDir\terraform-provider-aws_v4.67.0_x5.exe"
if (Test-Path $providerFile) {
    Write-Host "Provider file exists: $providerFile"
} else {
    Write-Host "Provider file not found. Checking for alternative names..."
    $files = Get-ChildItem -Path $providerDir -Filter "terraform-provider-aws*"
    if ($files.Count -gt 0) {
        $sourceFile = $files[0].FullName
        Write-Host "Found provider file: $sourceFile"
        Write-Host "Renaming to expected name..."
        Rename-Item -Path $sourceFile -NewName "terraform-provider-aws_v4.67.0_x5.exe" -Force
        Write-Host "Provider file renamed."
    } else {
        Write-Host "No provider files found in $providerDir"
        exit 1
    }
}

# Clean up
Write-Host "Cleaning up..."
Remove-Item -Path $zipFile -Force
Write-Host "Temporary files removed."

# Create a .terraformrc file
$terraformrcPath = "$env:USERPROFILE\.terraformrc"
Write-Host "Creating .terraformrc file at $terraformrcPath..."
@"
provider_installation {
  filesystem_mirror {
    path    = "$($env:USERPROFILE -replace '\\', '\\')\.terraform.d\plugins"
    include = ["registry.terraform.io/hashicorp/*"]
  }
  direct {
    exclude = ["registry.terraform.io/hashicorp/*"]
  }
}
"@ | Out-File -FilePath $terraformrcPath -Encoding utf8 -Force
Write-Host ".terraformrc file created."

# Initialize Terraform
Write-Host ""
Write-Host "Initializing Terraform..."
terraform init -plugin-dir="$env:USERPROFILE\.terraform.d\plugins"

if ($LASTEXITCODE -eq 0) {
Write-Host ""
Write-Host "✅ Terraform initialization completed successfully!"
Write-Host ""
Write-Host "You can now proceed with the deployment:"
Write-Host "1. terraform plan -var-file=dev.tfvars -out tfplan"
Write-Host "2. terraform apply ""tfplan"""
Write-Host ""
} else {
    Write-Host ""
    Write-Host "❌ Terraform initialization failed."
    Write-Host ""
    Write-Host "Please try the following:"
    Write-Host "1. Delete the .terraform directory: Remove-Item -Recurse -Force .terraform"
    Write-Host "2. Delete the .terraform.lock.hcl file: Remove-Item -Force .terraform.lock.hcl"
    Write-Host "3. Try initializing Terraform again with the -plugin-dir flag:"
    Write-Host "   terraform init -plugin-dir=`"$env:USERPROFILE\.terraform.d\plugins`""
    Write-Host ""
    Write-Host "If you're still having issues, try running the download_modules.ps1 script to fix module installation issues."
    Write-Host ""
}
