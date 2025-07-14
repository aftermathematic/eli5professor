#!/bin/bash

# Script to build and deploy separate Docker images to ECR for API and Bot services

echo "ELI5 Discord Bot - Separate Docker Images Deployment"
echo "===================================================="
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first:"
    echo "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install it first:"
    echo "https://docs.docker.com/get-docker/"
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

# Get ECR repository URLs from Terraform output
echo "Getting ECR repository URLs from Terraform output..."
API_ECR_REPO=$(terraform output -raw api_repository_url 2>/dev/null)
BOT_ECR_REPO=$(terraform output -raw bot_repository_url 2>/dev/null)

if [ -z "$API_ECR_REPO" ] || [ -z "$BOT_ECR_REPO" ]; then
    echo "Failed to get ECR repository URLs from Terraform output."
    echo "Please make sure the infrastructure has been deployed successfully."
    echo "API ECR Repo: $API_ECR_REPO"
    echo "Bot ECR Repo: $BOT_ECR_REPO"
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

# Login to ECR
echo ""
echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $(echo $API_ECR_REPO | cut -d'/' -f1)

if [ $? -ne 0 ]; then
    echo "Failed to login to ECR. Please check your AWS credentials."
    exit 1
fi

# Move to the root directory of the project
cd ..

# Build and push API Docker image
echo ""
echo "Building API Docker image..."
docker build -f Dockerfile -t $API_ECR_REPO:latest .

if [ $? -ne 0 ]; then
    echo "Failed to build API Docker image."
    exit 1
fi

echo "Pushing API Docker image to ECR..."
docker push $API_ECR_REPO:latest

if [ $? -ne 0 ]; then
    echo "Failed to push API Docker image to ECR."
    exit 1
fi

# Build and push Bot Docker image
echo ""
echo "Building Bot Docker image..."
docker build -f Dockerfile.bot -t $BOT_ECR_REPO:latest .

if [ $? -ne 0 ]; then
    echo "Failed to build Bot Docker image."
    exit 1
fi

echo "Pushing Bot Docker image to ECR..."
docker push $BOT_ECR_REPO:latest

if [ $? -ne 0 ]; then
    echo "Failed to push Bot Docker image to ECR."
    exit 1
fi

echo ""
echo "✅ Both Docker images successfully built and pushed to ECR!"
echo ""
echo "API Image: $API_ECR_REPO:latest"
echo "Bot Image: $BOT_ECR_REPO:latest"
echo ""
echo "Next steps:"
echo ""
echo "1. Update the App Runner services to use the new Docker images:"
echo "   ./update_app_runner_separate.sh"
echo ""
