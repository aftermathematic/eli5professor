#!/bin/bash

# Script to configure AWS credentials for the ELI5 Twitter Bot project

echo "ELI5 Twitter Bot - AWS Credentials Configuration"
echo "================================================"
echo ""
echo "This script will help you configure your AWS credentials."
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first:"
    echo "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

echo "Please enter your AWS credentials:"
echo ""

# Prompt for AWS Access Key ID
read -p "AWS Access Key ID: " aws_access_key_id

# Prompt for AWS Secret Access Key
read -p "AWS Secret Access Key: " aws_secret_access_key

# Prompt for AWS region
read -p "AWS Region (default: eu-west-3): " aws_region
aws_region=${aws_region:-eu-west-3}

# Prompt for output format
read -p "Output Format (default: json): " output_format
output_format=${output_format:-json}

# Configure AWS CLI
echo ""
echo "Configuring AWS CLI..."
aws configure set aws_access_key_id "$aws_access_key_id"
aws configure set aws_secret_access_key "$aws_secret_access_key"
aws configure set region "$aws_region"
aws configure set output "$output_format"

echo ""
echo "Testing AWS credentials..."
if aws sts get-caller-identity &> /dev/null; then
    echo "✅ AWS credentials configured successfully!"
    echo "Account: $(aws sts get-caller-identity --query 'Account' --output text)"
    echo "User: $(aws sts get-caller-identity --query 'Arn' --output text)"
else
    echo "❌ Failed to validate AWS credentials. Please check your credentials and try again."
    exit 1
fi

echo ""
echo "You can now proceed with deploying the infrastructure:"
echo "1. cd infra"
echo "2. terraform init"
echo "3. terraform plan -var-file=dev.tfvars -out=tfplan"
echo "4. terraform apply \"tfplan\""
echo ""
