@echo off
echo ELI5 Discord Bot - Fix Twitter References
echo ========================================
echo.

echo Step 1: Destroy incorrectly named App Runner services
echo ==================================================
echo.

echo Destroying services with Twitter references...
aws apprunner delete-service --service-arn $(aws apprunner list-services --region eu-west-3 --query "ServiceSummaryList[?contains(ServiceName, 'eli5-twitter-bot')].ServiceArn" --output text) --region eu-west-3 2>nul

echo.
echo Step 2: Clean up Terraform state
echo ==============================
echo.

echo Removing old state references...
terraform state rm module.twitter_bot_service 2>nul
terraform state rm module.api_service 2>nul

echo.
echo Step 3: Deploy with correct naming
echo ================================
echo.

echo Running terraform plan with correct app name...
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
echo Step 4: Verify correct naming
echo ===========================
echo.

echo Checking new service names...
aws apprunner list-services --region eu-west-3 --query "ServiceSummaryList[?contains(ServiceName, 'eli5-discord-bot')].[ServiceName,Status]" --output table

echo.
echo ✅ Twitter references have been fixed!
echo Your services should now be named with 'eli5-discord-bot' instead of 'eli5-twitter-bot'
echo.
pause
