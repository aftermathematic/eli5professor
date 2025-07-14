#!/bin/bash

# Script to update App Runner services to use the separate ECR images

echo "ELI5 Discord Bot - App Runner Update with Separate Images"
echo "========================================================="
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first:"
    echo "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "Terraform is not installed. Please install it first:"
    echo "https://developer.hashicorp.com/terraform/downloads"
    exit 1
fi

# Check if infrastructure has been deployed
if [ ! -f "terraform.tfstate" ]; then
    echo "Terraform state file not found. Please deploy the infrastructure first:"
    echo "1. terraform init"
    echo "2. terraform plan -var-file=dev.tfvars -out=tfplan"
    echo "3. terraform apply \"tfplan\""
    exit 1
fi

# Check if Docker images exist in ECR
echo "Checking if Docker images exist in ECR..."
API_ECR_REPO=$(terraform output -raw api_repository_url 2>/dev/null)
BOT_ECR_REPO=$(terraform output -raw bot_repository_url 2>/dev/null)

if [ -z "$API_ECR_REPO" ] || [ -z "$BOT_ECR_REPO" ]; then
    echo "Failed to get ECR repository URLs from Terraform output."
    echo "Please make sure the infrastructure has been deployed successfully."
    exit 1
fi

echo "API ECR Repository URL: $API_ECR_REPO"
echo "Bot ECR Repository URL: $BOT_ECR_REPO"

# Get AWS region
AWS_REGION=$(aws configure get region)
if [ -z "$AWS_REGION" ]; then
    AWS_REGION="eu-west-3"  # Default region
fi

echo "AWS Region: $AWS_REGION"

# Check if API image exists in ECR
echo "Checking for API Docker image in ECR..."
aws ecr describe-images --repository-name $(echo $API_ECR_REPO | cut -d'/' -f2) --region $AWS_REGION --query 'imageDetails[?contains(imageTags, `latest`)].imageTags' --output text

if [ $? -ne 0 ]; then
    echo "Failed to find API Docker image in ECR. Please push the images first:"
    echo "./deploy_docker_separate.sh"
    exit 1
fi

# Check if Bot image exists in ECR
echo "Checking for Bot Docker image in ECR..."
aws ecr describe-images --repository-name $(echo $BOT_ECR_REPO | cut -d'/' -f2) --region $AWS_REGION --query 'imageDetails[?contains(imageTags, `latest`)].imageTags' --output text

if [ $? -ne 0 ]; then
    echo "Failed to find Bot Docker image in ECR. Please push the images first:"
    echo "./deploy_docker_separate.sh"
    exit 1
fi

echo "Both Docker images found in ECR."

# Get App Runner service ARNs
echo "Getting App Runner service ARNs..."
DISCORD_BOT_SERVICE_ARN=$(terraform output -raw discord_bot_service_arn 2>/dev/null || echo "")
API_SERVICE_ARN=$(terraform output -raw api_service_arn 2>/dev/null || echo "")

if [ -z "$DISCORD_BOT_SERVICE_ARN" ] || [ -z "$API_SERVICE_ARN" ]; then
    echo "Failed to get App Runner service ARNs from Terraform output."
    echo "Please make sure the App Runner services have been deployed successfully."
    exit 1
fi

echo "Discord Bot Service ARN: $DISCORD_BOT_SERVICE_ARN"
echo "API Service ARN: $API_SERVICE_ARN"

# Update App Runner services to use the correct ECR images
echo ""
echo "Updating App Runner services to use the correct ECR images..."

# Get the IAM role ARN for ECR access - Discord Bot
DISCORD_BOT_ROLE_ARN=$(terraform output -raw discord_bot_service_ecr_role_arn 2>/dev/null || echo "")
if [ -z "$DISCORD_BOT_ROLE_ARN" ]; then
    echo "Failed to get Discord Bot service ECR role ARN from Terraform output."
    echo "Using the role name to create the ARN..."
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
    DISCORD_BOT_ROLE_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:role/eli5-discord-bot-discord-bot-dev-ecr-access-role"
fi
echo "Discord Bot ECR Role ARN: $DISCORD_BOT_ROLE_ARN"

# Update the Discord Bot service
echo "Updating Discord Bot service..."
aws apprunner update-service \
  --service-arn "$DISCORD_BOT_SERVICE_ARN" \
  --source-configuration "{
    \"AuthenticationConfiguration\": {
      \"AccessRoleArn\": \"$DISCORD_BOT_ROLE_ARN\"
    },
    \"ImageRepository\": {
      \"ImageIdentifier\": \"$BOT_ECR_REPO:latest\",
      \"ImageRepositoryType\": \"ECR\",
      \"ImageConfiguration\": {
        \"Port\": \"8000\",
        \"RuntimeEnvironmentVariables\": $(aws apprunner describe-service --service-arn $DISCORD_BOT_SERVICE_ARN --query 'Service.SourceConfiguration.ImageRepository.ImageConfiguration.RuntimeEnvironmentVariables' --output json)
      }
    },
    \"AutoDeploymentsEnabled\": true
  }"

if [ $? -ne 0 ]; then
    echo "Failed to update Discord Bot service. Exiting."
    exit 1
fi

# Get the IAM role ARN for ECR access - API
API_ROLE_ARN=$(terraform output -raw api_service_ecr_role_arn 2>/dev/null || echo "")
if [ -z "$API_ROLE_ARN" ]; then
    echo "Failed to get API service ECR role ARN from Terraform output."
    echo "Using the role name to create the ARN..."
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
    API_ROLE_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:role/eli5-discord-bot-api-dev-ecr-access-role"
fi
echo "API ECR Role ARN: $API_ROLE_ARN"

# Update the API service
echo "Updating API service..."
aws apprunner update-service \
  --service-arn "$API_SERVICE_ARN" \
  --source-configuration "{
    \"AuthenticationConfiguration\": {
      \"AccessRoleArn\": \"$API_ROLE_ARN\"
    },
    \"ImageRepository\": {
      \"ImageIdentifier\": \"$API_ECR_REPO:latest\",
      \"ImageRepositoryType\": \"ECR\",
      \"ImageConfiguration\": {
        \"Port\": \"8000\",
        \"RuntimeEnvironmentVariables\": $(aws apprunner describe-service --service-arn $API_SERVICE_ARN --query 'Service.SourceConfiguration.ImageRepository.ImageConfiguration.RuntimeEnvironmentVariables' --output json)
      }
    },
    \"AutoDeploymentsEnabled\": true
  }"

if [ $? -ne 0 ]; then
    echo "Failed to update API service. Exiting."
    exit 1
fi

echo ""
echo "✅ App Runner services updated successfully!"
echo ""
echo "You can now access your services at:"
echo "Discord Bot: $(terraform output -raw discord_bot_service_url 2>/dev/null || echo "Not available")"
echo "API: $(terraform output -raw api_service_url 2>/dev/null || echo "Not available")"
echo ""
echo "The services will take a few minutes to update and restart."
echo "You can check the status in the AWS App Runner console."
echo ""
