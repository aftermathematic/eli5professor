@echo off
echo ELI5 Discord Bot - Docker Build and Push
echo =======================================
echo.

REM Check if Docker is installed
where docker >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Docker is not installed. Please install Docker Desktop first:
    echo https://www.docker.com/products/docker-desktop
    exit /b 1
)

REM Check if AWS CLI is installed
where aws >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo AWS CLI is not installed. Please install it first:
    echo https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
    exit /b 1
)

REM Get AWS region and account ID
set AWS_REGION=eu-west-3
for /f "tokens=*" %%i in ('aws sts get-caller-identity --query Account --output text') do set AWS_ACCOUNT_ID=%%i

if "%AWS_ACCOUNT_ID%"=="" (
    echo Failed to get AWS Account ID. Please check your AWS credentials.
    exit /b 1
)

REM Set ECR repository details
set ECR_REPOSITORY=%AWS_ACCOUNT_ID%.dkr.ecr.%AWS_REGION%.amazonaws.com/eli5-discord-bot-dev
set IMAGE_TAG=latest

echo AWS Account ID: %AWS_ACCOUNT_ID%
echo AWS Region: %AWS_REGION%
echo ECR Repository: %ECR_REPOSITORY%
echo.

REM Login to ECR
echo Logging in to Amazon ECR...
aws ecr get-login-password --region %AWS_REGION% | docker login --username AWS --password-stdin %AWS_ACCOUNT_ID%.dkr.ecr.%AWS_REGION%.amazonaws.com

if %ERRORLEVEL% neq 0 (
    echo Failed to login to ECR. Please check your AWS credentials.
    exit /b 1
)

REM Change to project root directory (one level up from infra)
cd ..

REM Build the Docker image
echo.
echo Building Docker image...
docker build -t eli5-discord-bot:%IMAGE_TAG% .

if %ERRORLEVEL% neq 0 (
    echo Docker build failed. Please check the Dockerfile and try again.
    cd infra
    exit /b 1
)

REM Tag the image for ECR
echo.
echo Tagging image for ECR...
docker tag eli5-discord-bot:%IMAGE_TAG% %ECR_REPOSITORY%:%IMAGE_TAG%

if %ERRORLEVEL% neq 0 (
    echo Failed to tag Docker image.
    cd infra
    exit /b 1
)

REM Push the image to ECR
echo.
echo Pushing image to ECR...
docker push %ECR_REPOSITORY%:%IMAGE_TAG%

if %ERRORLEVEL% neq 0 (
    echo Failed to push Docker image to ECR.
    cd infra
    exit /b 1
)

REM Return to infra directory
cd infra

echo.
echo ✅ Docker image successfully built and pushed to ECR!
echo Image URI: %ECR_REPOSITORY%:%IMAGE_TAG%
echo.
