#!/bin/bash

# Script to force cleanup of resources for the ELI5 Twitter Bot project

echo "ELI5 Twitter Bot - Force Cleanup"
echo "==============================="
echo ""
echo "This script will force cleanup of all resources for the ELI5 Twitter Bot project."
echo "WARNING: This will delete all resources, including data in S3 buckets and ECR repositories."
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

# Confirm cleanup
read -p "Are you sure you want to proceed with the cleanup? (y/n): " confirm
if [[ $confirm != "y" && $confirm != "Y" ]]; then
    echo "Cleanup aborted."
    exit 0
fi

# Get AWS region
AWS_REGION=$(aws configure get region)
if [ -z "$AWS_REGION" ]; then
    AWS_REGION="eu-west-3"  # Default region
fi

echo "AWS Region: $AWS_REGION"

# Get resource names from Terraform output
echo "Getting resource names from Terraform output..."

# Get ECR repository URL
ECR_REPO=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")
if [ -n "$ECR_REPO" ]; then
    ECR_REPO_NAME=$(echo $ECR_REPO | cut -d'/' -f2)
    echo "ECR Repository: $ECR_REPO_NAME"
    
    # Delete all images in the ECR repository
    echo "Deleting all images in the ECR repository..."
    aws ecr list-images --repository-name $ECR_REPO_NAME --region $AWS_REGION --query 'imageIds[*]' --output json > images.json
    if [ -s images.json ]; then
        aws ecr batch-delete-image --repository-name $ECR_REPO_NAME --region $AWS_REGION --image-ids file://images.json || true
        echo "Images deleted."
    else
        echo "No images found in the ECR repository."
    fi
    rm -f images.json
fi

# Get S3 bucket name
S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
if [ -z "$S3_BUCKET" ]; then
    S3_BUCKET=$(terraform output -raw s3_bucket_id 2>/dev/null || echo "")
fi

if [ -n "$S3_BUCKET" ]; then
    echo "S3 Bucket: $S3_BUCKET"
    
    # Delete all objects in the S3 bucket
    echo "Deleting all objects in the S3 bucket..."
    aws s3 rm s3://$S3_BUCKET --recursive || true
    echo "Objects deleted."
fi

# Get App Runner service names
TWITTER_BOT_SERVICE=$(terraform output -raw twitter_bot_service_arn 2>/dev/null || echo "")
API_SERVICE=$(terraform output -raw api_service_arn 2>/dev/null || echo "")

if [ -n "$TWITTER_BOT_SERVICE" ] && [ "$TWITTER_BOT_SERVICE" != "Not deployed" ]; then
    echo "Twitter Bot Service: $TWITTER_BOT_SERVICE"
    
    # Delete the App Runner service
    echo "Deleting the Twitter Bot App Runner service..."
    SERVICE_NAME=$(echo $TWITTER_BOT_SERVICE | cut -d'/' -f2)
    aws apprunner delete-service --service-arn $TWITTER_BOT_SERVICE --region $AWS_REGION || true
    echo "Service deletion initiated. This may take a few minutes."
fi

if [ -n "$API_SERVICE" ] && [ "$API_SERVICE" != "Not deployed" ]; then
    echo "API Service: $API_SERVICE"
    
    # Delete the App Runner service
    echo "Deleting the API App Runner service..."
    SERVICE_NAME=$(echo $API_SERVICE | cut -d'/' -f2)
    aws apprunner delete-service --service-arn $API_SERVICE --region $AWS_REGION || true
    echo "Service deletion initiated. This may take a few minutes."
fi

# Get Lambda function names
TWITTER_BOT_LAMBDA=$(terraform output -raw twitter_bot_lambda_function_name 2>/dev/null || echo "")
API_LAMBDA=$(terraform output -raw api_lambda_function_name 2>/dev/null || echo "")

if [ -n "$TWITTER_BOT_LAMBDA" ] && [ "$TWITTER_BOT_LAMBDA" != "Not deployed" ]; then
    echo "Twitter Bot Lambda: $TWITTER_BOT_LAMBDA"
    
    # Delete the Lambda function
    echo "Deleting the Twitter Bot Lambda function..."
    aws lambda delete-function --function-name $TWITTER_BOT_LAMBDA --region $AWS_REGION || true
    echo "Lambda function deleted."
fi

if [ -n "$API_LAMBDA" ] && [ "$API_LAMBDA" != "Not deployed" ]; then
    echo "API Lambda: $API_LAMBDA"
    
    # Delete the Lambda function
    echo "Deleting the API Lambda function..."
    aws lambda delete-function --function-name $API_LAMBDA --region $AWS_REGION || true
    echo "Lambda function deleted."
fi

# Get API Gateway ID
API_GATEWAY_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
if [ -n "$API_GATEWAY_URL" ] && [ "$API_GATEWAY_URL" != "Not deployed" ]; then
    echo "API Gateway URL: $API_GATEWAY_URL"
    
    # Extract API Gateway ID from URL
    API_ID=$(echo $API_GATEWAY_URL | cut -d'.' -f1 | cut -d'/' -f3)
    if [ -n "$API_ID" ]; then
        echo "API Gateway ID: $API_ID"
        
        # Delete the API Gateway
        echo "Deleting the API Gateway..."
        aws apigatewayv2 delete-api --api-id $API_ID --region $AWS_REGION || true
        echo "API Gateway deleted."
    fi
fi

# Run Terraform destroy
echo ""
echo "Running Terraform destroy..."
terraform destroy -auto-approve

# Clean up Terraform state
echo ""
echo "Cleaning up Terraform state..."
rm -f terraform.tfstate*
rm -f .terraform.lock.hcl
rm -rf .terraform

echo ""
echo "✅ Cleanup completed successfully!"
echo ""
echo "You can now reinitialize Terraform and deploy the infrastructure again:"
echo "1. terraform init"
echo "2. terraform plan -var-file=dev.tfvars -out=tfplan"
echo "3. terraform apply \"tfplan\""
echo ""
