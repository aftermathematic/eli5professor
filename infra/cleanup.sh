#!/bin/bash

# Script to clean up App Runner services and start fresh

echo "ELI5 Twitter Bot - Cleanup Script"
echo "================================="
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

# Check if terraform.tfstate exists
if [ ! -f "terraform.tfstate" ]; then
    echo "Terraform state file not found. Nothing to clean up."
    exit 0
fi

# Get App Runner service ARNs
echo "Getting App Runner service ARNs..."
TWITTER_BOT_SERVICE_ARN=$(terraform output -raw twitter_bot_service_arn 2>/dev/null || echo "")
API_SERVICE_ARN=$(terraform output -raw api_service_arn 2>/dev/null || echo "")

# Delete App Runner services if they exist
if [ ! -z "$TWITTER_BOT_SERVICE_ARN" ]; then
    echo "Deleting Twitter Bot App Runner service..."
    aws apprunner delete-service --service-arn "$TWITTER_BOT_SERVICE_ARN"
    if [ $? -ne 0 ]; then
        echo "Failed to delete Twitter Bot App Runner service."
    fi
fi

if [ ! -z "$API_SERVICE_ARN" ]; then
    echo "Deleting API App Runner service..."
    aws apprunner delete-service --service-arn "$API_SERVICE_ARN"
    if [ $? -ne 0 ]; then
        echo "Failed to delete API App Runner service."
    fi
fi

# Wait for services to be deleted
echo ""
echo "Waiting for App Runner services to be deleted..."
echo "This may take a few minutes..."
echo ""

if [ ! -z "$TWITTER_BOT_SERVICE_ARN" ]; then
    aws apprunner describe-service --service-arn "$TWITTER_BOT_SERVICE_ARN" > /dev/null 2>&1
    while [ $? -eq 0 ]; do
        echo "Twitter Bot service is still being deleted..."
        sleep 30
        aws apprunner describe-service --service-arn "$TWITTER_BOT_SERVICE_ARN" > /dev/null 2>&1
    done
    echo "Twitter Bot service has been deleted."
fi

if [ ! -z "$API_SERVICE_ARN" ]; then
    aws apprunner describe-service --service-arn "$API_SERVICE_ARN" > /dev/null 2>&1
    while [ $? -eq 0 ]; do
        echo "API service is still being deleted..."
        sleep 30
        aws apprunner describe-service --service-arn "$API_SERVICE_ARN" > /dev/null 2>&1
    done
    echo "API service has been deleted."
fi

# Remove App Runner services from Terraform state
echo ""
echo "Removing App Runner services from Terraform state..."
terraform state rm module.twitter_bot_service.aws_apprunner_service.this 2>/dev/null
terraform state rm module.api_service.aws_apprunner_service.this 2>/dev/null

echo ""
echo "✅ Cleanup completed!"
echo ""
echo "You can now run the following commands to deploy the App Runner services:"
echo "1. terraform plan -var-file=dev.tfvars -out=tfplan"
echo "2. terraform apply \"tfplan\""
echo ""
