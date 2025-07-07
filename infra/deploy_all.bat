@echo off
REM Comprehensive deployment script for ELI5 Twitter Bot on Windows

echo ELI5 Twitter Bot - Comprehensive Deployment
echo ==========================================
echo.
echo This script will guide you through the entire deployment process.
echo.

REM Check if Terraform is installed
where terraform >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Terraform is not installed. Please install it first:
    echo https://developer.hashicorp.com/terraform/downloads
    exit /b 1
)

REM Check if AWS CLI is installed
where aws >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo AWS CLI is not installed. Please install it first:
    echo https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
    exit /b 1
)

REM Step 1: Fix Terraform initialization issues
echo Step 1: Fix Terraform initialization issues
echo -----------------------------------------
echo.
echo Attempting to fix Terraform initialization issues...
echo.

REM Try direct provider download
echo Running direct_provider_download.bat...
call direct_provider_download.bat

REM Check if initialization was successful
if %ERRORLEVEL% neq 0 (
    echo.
    echo Direct provider download failed. Trying download_modules.bat...
    call download_modules.bat
    
    if %ERRORLEVEL% neq 0 (
        echo.
        echo Module download failed. Please try manually:
        echo 1. Delete the .terraform directory: rmdir /s /q .terraform
        echo 2. Delete the .terraform.lock.hcl file: del .terraform.lock.hcl
        echo 3. Run terraform init again
        exit /b 1
    )
)

REM Step 2: Choose deployment type
echo.
echo Step 2: Choose deployment type
echo ----------------------------
echo.
echo Please choose a deployment type:
echo 1. App Runner (Docker-based)
echo 2. Lambda (Serverless)
echo.
set /p DEPLOYMENT_TYPE="Enter your choice (1 or 2): "

if "%DEPLOYMENT_TYPE%"=="1" (
    set DEPLOYMENT_VAR="deployment_type=app_runner"
    echo.
    echo You selected App Runner deployment.
) else if "%DEPLOYMENT_TYPE%"=="2" (
    set DEPLOYMENT_VAR="deployment_type=lambda"
    echo.
    echo You selected Lambda deployment.
) else (
    echo.
    echo Invalid choice. Please enter 1 or 2.
    exit /b 1
)

REM Step 3: Check for existing resources
echo.
echo Step 3: Check for existing resources
echo --------------------------------
echo.
echo Checking for existing resources...
echo.

REM Run the wait_for_deletion script
call wait_for_deletion.bat

REM Step 4: Deploy base infrastructure
echo.
echo Step 4: Deploy base infrastructure
echo --------------------------------
echo.
echo Deploying base infrastructure...
echo.

REM Run terraform plan
echo Running terraform plan...
terraform plan -var-file=dev.tfvars -var "%DEPLOYMENT_VAR%" -target=module.model_bucket -target=aws_secretsmanager_secret.twitter_credentials -target=aws_secretsmanager_secret.openai_credentials -out tfplan

if %ERRORLEVEL% neq 0 (
    echo.
    echo Terraform plan failed. Please check the error message above.
    exit /b 1
)

REM Run terraform apply
echo.
echo Running terraform apply...
terraform apply "tfplan"

if %ERRORLEVEL% neq 0 (
    echo.
    echo Terraform apply failed. Please check the error message above.
    exit /b 1
)

REM Step 4: Configure secrets
echo.
echo Step 4: Configure secrets
echo -----------------------
echo.
echo Please configure your Twitter and OpenAI API credentials in AWS Secrets Manager.
echo.
echo 1. Open the AWS Console: https://console.aws.amazon.com/secretsmanager/home
echo 2. Find the secrets "eli5-twitter-bot/twitter-credentials-dev" and "eli5-twitter-bot/openai-credentials-dev"
echo 3. Update the secret values with your API credentials
echo.
echo Press any key when you have configured your secrets...
pause > nul

REM Step 5: Deploy application
echo.
echo Step 5: Deploy application
echo ------------------------
echo.

if "%DEPLOYMENT_TYPE%"=="1" (
    echo Deploying App Runner services...
    echo.
    
    REM Build and push Docker image
    echo Building and pushing Docker image...
    call deploy_docker.bat
    
    if %ERRORLEVEL% neq 0 (
        echo.
        echo Docker deployment failed. Please check the error message above.
        exit /b 1
    )
    
    REM Deploy App Runner services
    echo.
    echo Deploying App Runner services...
    terraform plan -var-file=dev.tfvars -var "%DEPLOYMENT_VAR%" -out tfplan
    
    if %ERRORLEVEL% neq 0 (
        echo.
        echo Terraform plan failed. Please check the error message above.
        exit /b 1
    )
    
    terraform apply "tfplan"
    
    if %ERRORLEVEL% neq 0 (
        echo.
        echo Terraform apply failed. Please check the error message above.
        exit /b 1
    )
) else (
    echo Deploying Lambda functions...
    echo.
    
    REM Package Lambda functions
    echo Packaging Lambda functions...
    call package_lambda.bat
    
    if %ERRORLEVEL% neq 0 (
        echo.
        echo Lambda packaging failed. Please check the error message above.
        exit /b 1
    )
    
    REM Deploy Lambda functions
    echo.
    echo Deploying Lambda functions...
    terraform plan -var-file=dev.tfvars -var "%DEPLOYMENT_VAR%" -out tfplan
    
    if %ERRORLEVEL% neq 0 (
        echo.
        echo Terraform plan failed. Please check the error message above.
        exit /b 1
    )
    
    terraform apply "tfplan"
    
    if %ERRORLEVEL% neq 0 (
        echo.
        echo Terraform apply failed. Please check the error message above.
        exit /b 1
    )
)

REM Step 6: Display outputs
echo.
echo Step 6: Display outputs
echo ---------------------
echo.
echo Displaying Terraform outputs...
echo.
terraform output

echo.
echo ✅ Deployment completed successfully!
echo.
echo You can now access your services using the URLs above.
echo.
