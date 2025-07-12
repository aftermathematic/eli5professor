@echo off
echo Fixing Terraform State Issues
echo =============================
echo.

echo Step 1: Removing conflicting resources from Terraform state...
echo.

REM Remove secrets from state if they exist
terraform state rm aws_secretsmanager_secret.discord_credentials 2>nul
terraform state rm aws_secretsmanager_secret.openai_credentials 2>nul

echo Step 2: Running force cleanup to delete actual AWS resources...
echo.
powershell -ExecutionPolicy Bypass -File "force_delete_resources.ps1"

if %ERRORLEVEL% neq 0 (
    echo.
    echo Cleanup failed. Please check the error messages above.
    pause
    exit /b 1
)

echo.
echo Step 3: Refreshing Terraform state...
echo.
terraform refresh -var-file=dev.tfvars

echo.
echo Step 4: Running deployment...
echo.
call deploy_all.bat

echo.
echo State fix and deployment completed.
pause
