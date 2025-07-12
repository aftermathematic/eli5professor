@echo off
REM Script to fix Terraform initialization issues related to _netrc file on Windows

echo ELI5 Discord Bot - Fix Terraform Init
echo ====================================
echo.
echo This script will fix Terraform initialization issues related to the _netrc file.
echo.

REM Check if Terraform is installed
where terraform >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Terraform is not installed. Please install it first:
    echo https://developer.hashicorp.com/terraform/downloads
    exit /b 1
)

REM Create a temporary directory for Terraform
echo Creating a temporary directory for Terraform...
set TEMP_DIR=%TEMP%\terraform-providers
echo Temporary directory: %TEMP_DIR%

REM Create the provider mirror directory
echo Creating the provider mirror directory...
mkdir "%TEMP_DIR%\registry.terraform.io\hashicorp\aws\4.67.0\windows_amd64" 2>nul

REM Create a .terraformrc file in the home directory
echo Creating a .terraformrc file in the home directory...
(
echo provider_installation {
echo   filesystem_mirror {
echo     path    = "%TEMP_DIR:\=\\%"
echo     include = ["registry.terraform.io/hashicorp/*"]
echo   }
echo   direct {
echo     exclude = ["registry.terraform.io/hashicorp/*"]
echo   }
echo }
) > "%USERPROFILE%\.terraformrc"

echo .terraformrc file created.

REM Download the AWS provider manually
echo Downloading the AWS provider manually...
powershell -Command "& {Invoke-WebRequest -Uri 'https://releases.hashicorp.com/terraform-provider-aws/4.67.0/terraform-provider-aws_4.67.0_windows_amd64.zip' -OutFile '%TEMP_DIR%\registry.terraform.io\hashicorp\aws\4.67.0\windows_amd64\terraform-provider-aws_v4.67.0_x5.zip'}"

echo AWS provider downloaded.

REM Initialize Terraform
echo.
echo Initializing Terraform...
terraform init -plugin-dir="%TEMP_DIR%"

REM Check if initialization was successful
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
    echo Please try the following:
    echo 1. Delete the .terraform directory: rmdir /s /q .terraform
    echo 2. Delete the .terraform.lock.hcl file: del .terraform.lock.hcl
    echo 3. Try initializing Terraform again with the -plugin-dir flag:
    echo    terraform init -plugin-dir="%TEMP_DIR%"
    echo.
)
