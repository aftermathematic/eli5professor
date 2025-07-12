@echo off
echo ELI5 Discord Bot - Complete Deployment Fix
echo =========================================
echo.

echo Step 1: Build and push Docker image
echo ==================================
echo.
call deploy_docker.bat

if %ERRORLEVEL% neq 0 (
    echo Docker deployment failed. Please check the error messages above.
    pause
    exit /b 1
)

echo.
echo Step 2: Import existing secrets into Terraform state
echo ==================================================
echo.

echo Importing Discord credentials secret...
terraform import aws_secretsmanager_secret.discord_credentials "eli5-discord-bot/discord-credentials-dev" 2>nul
echo Importing OpenAI credentials secret...
terraform import aws_secretsmanager_secret.openai_credentials "eli5-discord-bot/openai-credentials-dev" 2>nul

echo.
echo Step 3: Deploy App Runner services with actual Docker image
echo =========================================================
echo.

echo Running terraform plan...
terraform plan -var-file=dev.tfvars -var "deployment_type=app_runner" -out tfplan

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
echo Step 4: Display deployment results
echo =================================
echo.
terraform output

echo.
echo ✅ Complete deployment finished!
echo.
echo Your ELI5 Discord Bot is now deployed with the actual Docker image.
echo Please configure your secrets in AWS Secrets Manager if you haven't already:
echo.
echo 1. Discord credentials: eli5-discord-bot/discord-credentials-dev
echo 2. OpenAI credentials: eli5-discord-bot/openai-credentials-dev
echo.
pause
