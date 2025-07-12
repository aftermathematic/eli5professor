@echo off
echo ELI5 Discord Bot - Quick Memory Fix
echo ==================================
echo.

echo Step 1: Update App Runner services with more memory
echo =================================================
echo.

echo Planning Terraform changes (increased memory to 2GB)...
terraform plan -var-file=dev.tfvars -out tfplan

if %ERRORLEVEL% neq 0 (
    echo Terraform plan failed. Please check the error message above.
    pause
    exit /b 1
)

echo.
echo Applying Terraform changes...
terraform apply "tfplan"

if %ERRORLEVEL% neq 0 (
    echo Terraform apply failed. Please check the error message above.
    pause
    exit /b 1
)

echo.
echo Step 2: Wait for deployment and check status
echo ==========================================
echo.

echo Waiting 90 seconds for services to update with more memory...
timeout /t 90 /nobreak

echo.
echo Checking service status...
aws apprunner list-services --region eu-west-3 --query "ServiceSummaryList[?contains(ServiceName, 'eli5-discord-bot')].[ServiceName,Status,ServiceUrl]" --output table

echo.
echo ✅ Memory increase complete!
echo.
echo Your services now have:
echo - 2GB memory (up from 0.5GB)
echo - 1 vCPU (up from 0.25 vCPU)
echo.
echo The services should now start successfully with the increased memory.
echo If they still fail, run fix_memory_and_redeploy.bat to use the lighter Docker image.
echo.
pause
