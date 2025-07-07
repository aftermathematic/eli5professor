#!/bin/bash

# Script to deploy Lambda functions for the ELI5 Twitter Bot project

echo "ELI5 Twitter Bot - Lambda Deployment"
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
    echo "2. terraform plan -var-file=dev.tfvars -out tfplan"
    echo "3. terraform apply \"tfplan\""
    exit 1
fi

# Check if S3 bucket exists
echo "Checking if S3 bucket exists..."
S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")

# If s3_bucket_name doesn't exist, try s3_bucket_id
if [ -z "$S3_BUCKET" ]; then
    echo "s3_bucket_name not found, trying s3_bucket_id..."
    S3_BUCKET=$(terraform output -raw s3_bucket_id 2>/dev/null || echo "")
fi

if [ -z "$S3_BUCKET" ]; then
    echo "Failed to get S3 bucket name from Terraform output."
    echo "Please make sure the infrastructure has been deployed successfully."
    exit 1
fi

echo "S3 Bucket: $S3_BUCKET"

# Check if Lambda packages exist in S3
echo "Checking if Lambda packages exist in S3..."
aws s3 ls "s3://$S3_BUCKET/lambda/twitter_bot.zip" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Twitter bot Lambda package not found in S3."
    echo "Please run the package_lambda.sh script first."
    exit 1
fi

aws s3 ls "s3://$S3_BUCKET/lambda/api.zip" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "API Lambda package not found in S3."
    echo "Please run the package_lambda.sh script first."
    exit 1
fi

echo "Lambda packages found in S3."

# Deploy Lambda functions with Terraform
echo ""
echo "Deploying Lambda functions with Terraform..."
terraform plan -var-file=dev.tfvars -var="deployment_type=lambda" -out tfplan
if [ $? -ne 0 ]; then
    echo "Failed to plan Terraform deployment. Exiting."
    exit 1
fi

terraform apply "tfplan"
if [ $? -ne 0 ]; then
    echo "Failed to apply Terraform deployment. Exiting."
    exit 1
fi

# Get Lambda function URLs
echo ""
echo "Lambda functions deployed successfully!"
echo ""
echo "Twitter Bot Lambda Function: $(terraform output -raw twitter_bot_lambda_function_name 2>/dev/null || echo "Not available")"
echo "API Gateway URL: $(terraform output -raw api_gateway_url 2>/dev/null || echo "Not available")"
echo ""
echo "The Twitter bot will run automatically according to the schedule."
echo "You can invoke it manually with:"
echo "aws lambda invoke --function-name $(terraform output -raw twitter_bot_lambda_function_name 2>/dev/null || echo "function-name") --payload '{}' response.json"
echo ""
