# PowerShell script to manually download Terraform modules

Write-Host "ELI5 Discord Bot - Download Terraform Modules (PowerShell)"
Write-Host "========================================================="
Write-Host ""
Write-Host "This script will manually download Terraform modules to fix initialization issues."
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

# Create the modules directory structure
Write-Host "Creating modules directory structure..."
New-Item -ItemType Directory -Path ".terraform\modules" -Force | Out-Null
Write-Host "Modules directory: .terraform\modules"

# Function to download and extract a module
function Download-Module {
    param (
        [string]$moduleName,
        [string]$moduleSource
    )
    
    $moduleDir = ".terraform\modules\$moduleName"
    
    Write-Host ""
    Write-Host "Downloading module: $moduleName"
    Write-Host "Source: $moduleSource"
    
    # Create the module directory
    New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null
    
    # Copy the module files
    Copy-Item -Path "$moduleSource\*" -Destination $moduleDir -Recurse -Force
    
    Write-Host "Module $moduleName downloaded to $moduleDir"
}

# Download the modules
Download-Module -moduleName "model_bucket" -moduleSource "modules\s3-bucket"
Download-Module -moduleName "app_repository" -moduleSource "modules\ecr-repository"
Download-Module -moduleName "discord_bot_service" -moduleSource "modules\apprunner-service"
Download-Module -moduleName "api_service" -moduleSource "modules\apprunner-service"
Download-Module -moduleName "discord_bot_lambda" -moduleSource "modules\lambda-function"
Download-Module -moduleName "api_lambda" -moduleSource "modules\lambda-function"

# Create a modules.json file
Write-Host "Creating modules.json file..."
$modulesJson = @"
{
  "Modules": [
    {
      "Key": "model_bucket",
      "Source": "./modules/s3-bucket",
      "Dir": "modules/s3-bucket"
    },
    {
      "Key": "app_repository",
      "Source": "./modules/ecr-repository",
      "Dir": "modules/ecr-repository"
    },
    {
      "Key": "discord_bot_service",
      "Source": "./modules/apprunner-service",
      "Dir": "modules/apprunner-service"
    },
    {
      "Key": "api_service",
      "Source": "./modules/apprunner-service",
      "Dir": "modules/apprunner-service"
    },
    {
      "Key": "discord_bot_lambda",
      "Source": "./modules/lambda-function",
      "Dir": "modules/lambda-function"
    },
    {
      "Key": "api_lambda",
      "Source": "./modules/lambda-function",
      "Dir": "modules/lambda-function"
    }
  ]
}
"@
$modulesJson | Out-File -FilePath ".terraform\modules\modules.json" -Encoding utf8 -Force
Write-Host "modules.json file created."

Write-Host ""
Write-Host "✅ Terraform modules downloaded successfully!"
Write-Host ""
Write-Host "Now try running terraform init again:"
Write-Host "terraform init"
Write-Host ""

# Initialize Terraform
Write-Host "Initializing Terraform..."
terraform init

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Terraform initialization completed successfully!"
    Write-Host ""
    Write-Host "You can now proceed with the deployment:"
    Write-Host "1. terraform plan -var-file=dev.tfvars -out=tfplan"
    Write-Host "2. terraform apply `"tfplan`""
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "❌ Terraform initialization failed."
    Write-Host ""
    Write-Host "Please try the following:"
    Write-Host "1. Delete the .terraform directory: Remove-Item -Recurse -Force .terraform"
    Write-Host "2. Delete the .terraform.lock.hcl file: Remove-Item -Force .terraform.lock.hcl"
    Write-Host "3. Try running the fix_terraform_init.ps1 script to fix provider installation issues:"
    Write-Host "   .\fix_terraform_init.ps1"
    Write-Host ""
}
