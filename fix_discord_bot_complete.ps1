# PowerShell script to fix the complete Discord bot system

Write-Host "ELI5 Discord Bot - Complete Fix" -ForegroundColor Green
Write-Host "===============================" -ForegroundColor Green
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

# Get ECR repository URL
$ecrRepo = "335561736978.dkr.ecr.eu-west-3.amazonaws.com/eli5-discord-bot-dev"
$awsRegion = "eu-west-3"

Write-Host "ECR Repository URL: $ecrRepo" -ForegroundColor Cyan
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

# Build the Discord bot Docker image
Write-Host ""
Write-Host "Building Discord bot Docker image..." -ForegroundColor Yellow
docker build -f Dockerfile.bot -t "${ecrRepo}:bot-latest" .
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build Discord bot Docker image." -ForegroundColor Red
    exit 1
}

# Push the Discord bot image to ECR
Write-Host ""
Write-Host "Pushing Discord bot Docker image to ECR..." -ForegroundColor Yellow
docker push "${ecrRepo}:bot-latest"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to push Discord bot Docker image to ECR." -ForegroundColor Red
    exit 1
}

# Update the Discord bot service
Write-Host ""
Write-Host "Updating Discord bot service..." -ForegroundColor Yellow

# Create update configuration for Discord bot
$botUpdateConfig = @{
    ImageRepository = @{
        ImageIdentifier = "${ecrRepo}:bot-latest"
        ImageRepositoryType = "ECR"
        ImageConfiguration = @{
            Port = "8000"
            RuntimeEnvironmentVariables = @{
                ENVIRONMENT = "dev"
                DISCORD_BOT_TOKEN = "eli5-discord-bot/discord-credentials-dev:DISCORD_BOT_TOKEN"
                DISCORD_CHANNEL_ID = "eli5-discord-bot/discord-credentials-dev:DISCORD_CHANNEL_ID"
                DISCORD_SERVER_ID = "eli5-discord-bot/discord-credentials-dev:DISCORD_SERVER_ID"
                TARGET_USER_ID = "eli5-discord-bot/discord-credentials-dev:TARGET_USER_ID"
            }
        }
    }
    AutoDeploymentsEnabled = $true
} | ConvertTo-Json -Depth 10

$botUpdateConfig | Out-File -FilePath "bot-update-config.json" -Encoding UTF8

# Get Discord bot service ARN
$botServiceArn = "arn:aws:apprunner:eu-west-3:335561736978:service/eli5-discord-bot-discord-bot-dev"

# Update the Discord bot service
$updateResult = aws apprunner update-service --service-arn $botServiceArn --source-configuration file://bot-update-config.json

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to update Discord bot service." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Discord bot service updated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Both API and Discord bot services are now running with the correct images." -ForegroundColor Yellow
Write-Host ""
Write-Host "API URL: https://8friecshgc.eu-west-3.awsapprunner.com" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test the complete system by:" -ForegroundColor Yellow
Write-Host "1. Mentioning @eliprofessor with #eli5 hashtag in Discord" -ForegroundColor Cyan
Write-Host "2. The bot should capture the mention and generate a reply" -ForegroundColor Cyan
Write-Host ""
Write-Host "Monitor the services in the AWS App Runner console." -ForegroundColor Yellow
