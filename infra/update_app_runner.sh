#!/bin/bash

# Script to update App Runner services to use the actual ECR image

echo "ELI5 Twitter Bot - App Runner Update"
echo "==================================="
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

# Check if Docker image has been pushed to ECR
echo "Checking if Docker image exists in ECR..."
ECR_REPO=$(terraform output -raw ecr_repository_url)

if [ -z "$ECR_REPO" ]; then
    echo "Failed to get ECR repository URL from Terraform output."
    echo "Please make sure the infrastructure has been deployed successfully."
    exit 1
fi

echo "ECR Repository URL: $ECR_REPO"

# Get AWS region
AWS_REGION=$(aws configure get region)
if [ -z "$AWS_REGION" ]; then
    AWS_REGION="eu-west-3"  # Default region
fi

echo "AWS Region: $AWS_REGION"

# Check if image exists in ECR
echo "Checking for Docker image in ECR..."
aws ecr describe-images --repository-name $(echo $ECR_REPO | cut -d'/' -f2) --region $AWS_REGION --query 'imageDetails[?contains(imageTags, `latest`)].imageTags' --output text

if [ $? -ne 0 ]; then
    echo "Failed to find Docker image in ECR. Please push the image first:"
    echo "./deploy_docker.sh"
    exit 1
fi

echo "Docker image found in ECR."

# Get App Runner service ARNs
echo "Getting App Runner service ARNs..."
TWITTER_BOT_SERVICE_ARN=$(terraform output -raw twitter_bot_service_arn 2>/dev/null || echo "")
API_SERVICE_ARN=$(terraform output -raw api_service_arn 2>/dev/null || echo "")

if [ -z "$TWITTER_BOT_SERVICE_ARN" ] || [ -z "$API_SERVICE_ARN" ]; then
    echo "Failed to get App Runner service ARNs from Terraform output."
    echo "Please make sure the App Runner services have been deployed successfully."
    exit 1
fi

echo "Twitter Bot Service ARN: $TWITTER_BOT_SERVICE_ARN"
echo "API Service ARN: $API_SERVICE_ARN"

# Update App Runner services to use the actual ECR image
echo ""
echo "Updating App Runner services to use the actual ECR image..."

# Get the IAM role ARN for ECR access
TWITTER_BOT_ROLE_ARN=$(terraform output -raw twitter_bot_service_ecr_role_arn 2>/dev/null || echo "")
if [ -z "$TWITTER_BOT_ROLE_ARN" ]; then
    echo "Failed to get Twitter Bot service ECR role ARN from Terraform output."
    echo "Using the role name to create the ARN..."
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
    TWITTER_BOT_ROLE_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:role/eli5-twitter-bot-twitter-bot-dev-ecr-access-role"
fi
echo "Twitter Bot ECR Role ARN: $TWITTER_BOT_ROLE_ARN"

# Update the Twitter Bot service
echo "Updating Twitter Bot service..."
aws apprunner update-service \
  --service-arn "$TWITTER_BOT_SERVICE_ARN" \
  --source-configuration "{
    \"AuthenticationConfiguration\": {
      \"AccessRoleArn\": \"$TWITTER_BOT_ROLE_ARN\"
    },
    \"ImageRepository\": {
      \"ImageIdentifier\": \"$ECR_REPO:latest\",
      \"ImageRepositoryType\": \"ECR\",
      \"ImageConfiguration\": {
        \"Port\": \"8000\",
        \"RuntimeEnvironmentVariables\": $(aws apprunner describe-service --service-arn $TWITTER_BOT_SERVICE_ARN --query 'Service.SourceConfiguration.ImageRepository.ImageConfiguration.RuntimeEnvironmentVariables' --output json)
      }
    },
    \"AutoDeploymentsEnabled\": true
  }"

if [ $? -ne 0 ]; then
    echo "Failed to update Twitter Bot service. Exiting."
    exit 1
fi

# Get the IAM role ARN for ECR access
API_ROLE_ARN=$(terraform output -raw api_service_ecr_role_arn 2>/dev/null || echo "")
if [ -z "$API_ROLE_ARN" ]; then
    echo "Failed to get API service ECR role ARN from Terraform output."
    echo "Using the role name to create the ARN..."
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
    API_ROLE_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:role/eli5-twitter-bot-api-dev-ecr-access-role"
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
      \"ImageIdentifier\": \"$ECR_REPO:latest\",
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
echo "Twitter Bot: $(terraform output -raw twitter_bot_service_url 2>/dev/null || echo "Not available")"
echo "API: $(terraform output -raw api_service_url 2>/dev/null || echo "Not available")"
echo ""
