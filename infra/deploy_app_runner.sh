#!/bin/bash

# Script to deploy App Runner services for the ELI5 Discord Bot project

echo "ELI5 Discord Bot - App Runner Deployment"
echo "========================================="
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
    echo "2. terraform plan -var-file=dev.tfvars -out tfplan"
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

# Check if app_runner.tf exists
if [ ! -f "app_runner.tf" ]; then
    echo "app_runner.tf file not found. Please make sure the file exists."
    exit 1
fi

# Apply Terraform configuration
echo ""
echo "Applying Terraform configuration to deploy App Runner services..."
terraform plan -var-file=dev.tfvars -var="deployment_type=app_runner" -out tfplan
if [ $? -ne 0 ]; then
    echo "Failed to plan Terraform deployment. Exiting."
    exit 1
fi

terraform apply "tfplan"
if [ $? -ne 0 ]; then
    echo "Failed to apply Terraform deployment. Exiting."
    exit 1
fi

echo ""
echo "✅ App Runner services deployed successfully!"
echo ""
echo "You can now access your services at:"
echo "Discord Bot: $(terraform output -raw discord_bot_service_url 2>/dev/null || echo "Not available")"
echo "API: $(terraform output -raw api_service_url 2>/dev/null || echo "Not available")"
echo ""
