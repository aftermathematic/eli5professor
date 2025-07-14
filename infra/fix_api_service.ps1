# PowerShell script to fix the API service by building and deploying the correct Docker image

Write-Host "ELI5 Discord Bot - Fix API Service" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host ""

# Check if Docker is available
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Docker is not installed or not in PATH. Please install Docker first." -ForegroundColor Red
    exit 1
}

# Check if AWS CLI is available
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "AWS CLI is not installed or not in PATH. Please install AWS CLI first." -ForegroundColor Red
    exit 1
}

# Get the current directory
$currentDir = Get-Location

# Change to infra directory if not already there
if (-not (Test-Path "terraform.tfstate")) {
    if (Test-Path "../infra/terraform.tfstate") {
        Set-Location "../infra"
    } elseif (Test-Path "infra/terraform.tfstate") {
        Set-Location "infra"
    } else {
        Write-Host "Terraform state file not found. Please run from the correct directory." -ForegroundColor Red
        exit 1
    }
}

# Get ECR repository URL from terraform output
Write-Host "Getting ECR repository URL..." -ForegroundColor Yellow
$ecrRepo = terraform output -raw ecr_repository_url 2>$null
if (-not $ecrRepo) {
    Write-Host "Failed to get ECR repository URL from Terraform output." -ForegroundColor Red
    exit 1
}

Write-Host "ECR Repository URL: $ecrRepo" -ForegroundColor Cyan

# Get AWS region
$awsRegion = aws configure get region
if (-not $awsRegion) {
    $awsRegion = "eu-west-3"  # Default region
}

Write-Host "AWS Region: $awsRegion" -ForegroundColor Cyan

# Login to ECR
Write-Host ""
Write-Host "Logging in to ECR..." -ForegroundColor Yellow
$loginCommand = aws ecr get-login-password --region $awsRegion
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to get ECR login password." -ForegroundColor Red
    exit 1
}

$loginCommand | docker login --username AWS --password-stdin $ecrRepo.Split('/')[0]
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to login to ECR." -ForegroundColor Red
    exit 1
}

# Change to project root directory
Set-Location ..

# Build the API Docker image using the correct Dockerfile
Write-Host ""
Write-Host "Building API Docker image..." -ForegroundColor Yellow
docker build -f Dockerfile -t "${ecrRepo}:api-latest" .
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build API Docker image." -ForegroundColor Red
    exit 1
}

# Push the API image to ECR
Write-Host ""
Write-Host "Pushing API Docker image to ECR..." -ForegroundColor Yellow
docker push "${ecrRepo}:api-latest"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to push API Docker image to ECR." -ForegroundColor Red
    exit 1
}

# Change back to infra directory
Set-Location infra

# Get App Runner service ARN for API
Write-Host ""
Write-Host "Getting API service ARN..." -ForegroundColor Yellow
$apiServiceArn = terraform output -raw api_service_arn 2>$null
if (-not $apiServiceArn) {
    Write-Host "Failed to get API service ARN from Terraform output." -ForegroundColor Red
    exit 1
}

Write-Host "API Service ARN: $apiServiceArn" -ForegroundColor Cyan

# Get ECR access role ARN
$apiRoleArn = terraform output -raw api_service_ecr_role_arn 2>$null
if (-not $apiRoleArn) {
    Write-Host "Failed to get API service ECR role ARN from Terraform output." -ForegroundColor Red
    $awsAccountId = aws sts get-caller-identity --query "Account" --output text
    $apiRoleArn = "arn:aws:iam::${awsAccountId}:role/eli5-discord-bot-api-dev-ecr-access-role"
}

Write-Host "API ECR Role ARN: $apiRoleArn" -ForegroundColor Cyan

# Update the API service to use the correct image
Write-Host ""
Write-Host "Updating API service to use the correct Docker image..." -ForegroundColor Yellow

# Get current environment variables
$currentEnvVars = aws apprunner describe-service --service-arn $apiServiceArn --query 'Service.SourceConfiguration.ImageRepository.ImageConfiguration.RuntimeEnvironmentVariables' --output json

# Update the service
$updateResult = aws apprunner update-service --service-arn $apiServiceArn --source-configuration "{
    `"AuthenticationConfiguration`": {
        `"AccessRoleArn`": `"$apiRoleArn`"
    },
    `"ImageRepository`": {
        `"ImageIdentifier`": `"${ecrRepo}:api-latest`",
        `"ImageRepositoryType`": `"ECR`",
        `"ImageConfiguration`": {
            `"Port`": `"8000`",
            `"RuntimeEnvironmentVariables`": $currentEnvVars
        }
    },
    `"AutoDeploymentsEnabled`": true
}"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to update API service." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ API service updated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "The API service will take a few minutes to update and restart." -ForegroundColor Yellow
Write-Host "You can check the status in the AWS App Runner console." -ForegroundColor Yellow
Write-Host ""
Write-Host "API URL: https://8friecshgc.eu-west-3.awsapprunner.com" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test the API with:" -ForegroundColor Yellow
Write-Host 'curl -X POST https://8friecshgc.eu-west-3.awsapprunner.com/explain -H "Content-Type: application/json" -d "{\"subject\": \"mlops\"}"' -ForegroundColor Cyan
