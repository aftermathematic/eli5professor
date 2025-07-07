@echo off
REM Script to directly download and install the AWS provider for Terraform on Windows

echo ELI5 Twitter Bot - Direct Provider Download
echo =========================================
echo.
echo This script will directly download and install the AWS provider for Terraform.
echo.

REM Check if Terraform is installed
where terraform >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Terraform is not installed. Please install it first:
    echo https://developer.hashicorp.com/terraform/downloads
    exit /b 1
)

REM Create the provider directory structure
echo Creating provider directory structure...
set PROVIDER_DIR=%USERPROFILE%\.terraform.d\plugins\registry.terraform.io\hashicorp\aws\4.67.0\windows_amd64
mkdir "%PROVIDER_DIR%" 2>nul

REM Download the AWS provider
echo Downloading AWS provider...
powershell -Command "& {Invoke-WebRequest -Uri 'https://releases.hashicorp.com/terraform-provider-aws/4.67.0/terraform-provider-aws_4.67.0_windows_amd64.zip' -OutFile '%TEMP%\terraform-provider-aws.zip'}"

REM Extract the AWS provider
echo Extracting AWS provider...
powershell -Command "& {Expand-Archive -Path '%TEMP%\terraform-provider-aws.zip' -DestinationPath '%PROVIDER_DIR%' -Force}"

REM Rename the provider file
echo Renaming provider file...
ren "%PROVIDER_DIR%\terraform-provider-aws_v4.67.0_x5.exe" "terraform-provider-aws_v4.67.0_x5.exe"

REM Clean up
echo Cleaning up...
del "%TEMP%\terraform-provider-aws.zip"

echo.
echo ✅ AWS provider installed successfully!
echo.
echo Now try running terraform init with the -plugin-dir flag:
echo terraform init -plugin-dir="%USERPROFILE%\.terraform.d\plugins"
echo.

REM Run terraform init with the plugin directory
echo Running terraform init...
terraform init -plugin-dir="%USERPROFILE%\.terraform.d\plugins"

if %ERRORLEVEL% equ 0 (
echo.
echo ✅ Terraform initialization completed successfully!
echo.
echo You can now proceed with the deployment:
echo 1. terraform plan -var-file=dev.tfvars -out tfplan
echo 2. terraform apply "tfplan"
echo.
) else (
    echo.
    echo ❌ Terraform initialization failed.
    echo.
    echo Please try running the download_modules script to fix module installation issues:
    echo download_modules.bat
    echo.
)
