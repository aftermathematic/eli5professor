@echo off
echo ELI5 Discord Bot - Fix Memory Issues and Redeploy
echo ================================================
echo.

echo Step 1: Build lighter Docker image
echo ================================
echo.

echo Building new Docker image without heavy ML libraries...
cd ..
docker build -f Dockerfile.light -t eli5-discord-bot:light .
cd infra

if %ERRORLEVEL% neq 0 (
    echo Docker build failed. Please check the error message above.
    pause
    exit /b 1
)

echo.
echo Step 2: Tag and push to ECR
echo =========================
echo.

echo Getting ECR login token...
aws ecr get-login-password --region eu-west-3 | docker login --username AWS --password-stdin 335561736978.dkr.ecr.eu-west-3.amazonaws.com

echo.
echo Tagging image for ECR...
docker tag eli5-discord-bot:light 335561736978.dkr.ecr.eu-west-3.amazonaws.com/eli5-discord-bot-dev:latest

echo.
echo Pushing to ECR...
docker push 335561736978.dkr.ecr.eu-west-3.amazonaws.com/eli5-discord-bot-dev:latest

if %ERRORLEVEL% neq 0 (
    echo Docker push failed. Please check the error message above.
    pause
    exit /b 1
)

echo.
echo Step 3: Update App Runner services with more memory
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
echo Step 4: Wait for deployment and check status
echo ==========================================
echo.

echo Waiting 60 seconds for services to update...
timeout /t 60 /nobreak

echo.
echo Checking service status...
aws apprunner list-services --region eu-west-3 --query "ServiceSummaryList[?contains(ServiceName, 'eli5-discord-bot')].[ServiceName,Status,ServiceUrl]" --output table

echo.
echo ✅ Memory fix and redeployment complete!
echo.
echo Your services now have:
echo - 2GB memory (up from 0.5GB)
echo - 1 vCPU (up from 0.25 vCPU)
echo - Lighter Docker image without heavy ML libraries
echo.
echo The services should now start successfully without memory issues.
echo.
pause
