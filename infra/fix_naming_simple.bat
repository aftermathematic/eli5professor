@echo off
echo ELI5 Discord Bot - Fix Service Names
echo ===================================
echo.

echo Step 1: Delete incorrectly named App Runner services
echo =================================================
echo.

echo Listing current services...
aws apprunner list-services --region eu-west-3 --query "ServiceSummaryList[?contains(ServiceName, 'eli5-twitter-bot')].[ServiceName,ServiceArn]" --output table

echo.
echo Deleting services with Twitter references...
for /f "tokens=2" %%i in ('aws apprunner list-services --region eu-west-3 --query "ServiceSummaryList[?contains(ServiceName, 'eli5-twitter-bot')].ServiceArn" --output text') do (
    if not "%%i"=="" (
        echo Deleting service: %%i
        aws apprunner delete-service --service-arn %%i --region eu-west-3
    )
)

echo.
echo Step 2: Wait for services to be deleted
echo =====================================
echo.
echo Waiting 30 seconds for services to be deleted...
timeout /t 30 /nobreak

echo.
echo Step 3: Deploy with correct names
echo ===============================
echo.

echo Running terraform plan with correct naming...
terraform plan -var-file=dev.tfvars -out tfplan

if %ERRORLEVEL% neq 0 (
    echo Terraform plan failed. Please check the error message above.
    pause
    exit /b 1
)

echo.
echo Running terraform apply...
terraform apply "tfplan"

if %ERRORLEVEL% neq 0 (
    echo Terraform apply failed. Please check the error message above.
    pause
    exit /b 1
)

echo.
echo Step 4: Verify new service names
echo ==============================
echo.

echo Checking new services...
aws apprunner list-services --region eu-west-3 --query "ServiceSummaryList[?contains(ServiceName, 'eli5-discord-bot')].[ServiceName,Status,ServiceUrl]" --output table

echo.
echo ✅ Service names have been fixed!
echo Your services should now be named with 'eli5-discord-bot' prefix.
echo.
pause
