#!/bin/bash

# Script to build and deploy Docker image to ECR for the ELI5 Twitter Bot project

echo "ELI5 Twitter Bot - Docker Image Deployment"
echo "=========================================="
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

# Get ECR repository URL from Terraform output
echo "Getting ECR repository URL from Terraform output..."
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

# Login to ECR
echo ""
echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO

if [ $? -ne 0 ]; then
    echo "Failed to login to ECR. Please check your AWS credentials."
    exit 1
fi

# Build and tag Docker image
echo ""
echo "Building Docker image..."
cd ..  # Move to the root directory of the project
docker build -t $ECR_REPO:latest .

if [ $? -ne 0 ]; then
    echo "Failed to build Docker image."
    exit 1
fi

# Push image to ECR
echo ""
echo "Pushing Docker image to ECR..."
docker push $ECR_REPO:latest

if [ $? -ne 0 ]; then
    echo "Failed to push Docker image to ECR."
    exit 1
fi

echo ""
echo "✅ Docker image successfully built and pushed to ECR!"
echo ""
echo "Next steps:"
echo ""
echo "1. If you haven't deployed the App Runner services yet, run:"
echo "   ./deploy_app_runner.sh"
echo ""
echo "2. If you've already deployed the App Runner services, update them to use the actual Docker image:"
echo "   ./update_app_runner.sh"
echo ""
