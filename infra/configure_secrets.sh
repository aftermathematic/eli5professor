#!/bin/bash

# Script to configure secrets in AWS Secrets Manager for the ELI5 Twitter Bot project

echo "ELI5 Twitter Bot - Secrets Configuration"
echo "========================================"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first:"
    echo "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
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

# Get AWS region
AWS_REGION=$(aws configure get region)
if [ -z "$AWS_REGION" ]; then
    AWS_REGION="eu-west-3"  # Default region
fi

echo "AWS Region: $AWS_REGION"

# Get app name and environment from Terraform variables
APP_NAME=$(grep 'app_name' dev.tfvars | cut -d '=' -f2 | tr -d ' "')
ENVIRONMENT=$(grep 'environment' dev.tfvars | cut -d '=' -f2 | tr -d ' "')

if [ -z "$APP_NAME" ] || [ -z "$ENVIRONMENT" ]; then
    APP_NAME="eli5-twitter-bot"  # Default app name
    ENVIRONMENT="dev"  # Default environment
fi

echo "App Name: $APP_NAME"
echo "Environment: $ENVIRONMENT"

# Secret names
TWITTER_SECRET_NAME="$APP_NAME/twitter-credentials-$ENVIRONMENT"
OPENAI_SECRET_NAME="$APP_NAME/openai-credentials-$ENVIRONMENT"

echo ""
echo "Configuring Twitter API credentials..."
echo "Please enter your Twitter API credentials:"

# Prompt for Twitter API credentials
read -p "Twitter API Key: " TWITTER_API_KEY
read -p "Twitter API Secret: " TWITTER_API_SECRET
read -p "Twitter Access Token: " TWITTER_ACCESS_TOKEN
read -p "Twitter Access Token Secret: " TWITTER_ACCESS_TOKEN_SECRET
read -p "Twitter Bearer Token: " TWITTER_BEARER_TOKEN
read -p "Twitter Account Handle: " TWITTER_ACCOUNT_HANDLE
read -p "Twitter User ID: " TWITTER_USER_ID

# Create Twitter credentials JSON
TWITTER_SECRET_VALUE="{
  \"TWITTER_API_KEY\": \"$TWITTER_API_KEY\",
  \"TWITTER_API_SECRET\": \"$TWITTER_API_SECRET\",
  \"TWITTER_ACCESS_TOKEN\": \"$TWITTER_ACCESS_TOKEN\",
  \"TWITTER_ACCESS_TOKEN_SECRET\": \"$TWITTER_ACCESS_TOKEN_SECRET\",
  \"TWITTER_BEARER_TOKEN\": \"$TWITTER_BEARER_TOKEN\",
  \"TWITTER_ACCOUNT_HANDLE\": \"$TWITTER_ACCOUNT_HANDLE\",
  \"TWITTER_USER_ID\": \"$TWITTER_USER_ID\"
}"

echo ""
echo "Configuring OpenAI API credentials..."
echo "Please enter your OpenAI API credentials:"

# Prompt for OpenAI API credentials
read -p "OpenAI API Key: " OPENAI_API_KEY

# Create OpenAI credentials JSON
OPENAI_SECRET_VALUE="{
  \"OPENAI_API_KEY\": \"$OPENAI_API_KEY\"
}"

# Store secrets in AWS Secrets Manager
echo ""
echo "Storing secrets in AWS Secrets Manager..."

echo "Storing Twitter credentials..."
aws secretsmanager put-secret-value \
  --secret-id "$TWITTER_SECRET_NAME" \
  --secret-string "$TWITTER_SECRET_VALUE" \
  --region "$AWS_REGION"

if [ $? -ne 0 ]; then
    echo "Failed to store Twitter credentials in AWS Secrets Manager."
    exit 1
fi

echo "Storing OpenAI credentials..."
aws secretsmanager put-secret-value \
  --secret-id "$OPENAI_SECRET_NAME" \
  --secret-string "$OPENAI_SECRET_VALUE" \
  --region "$AWS_REGION"

if [ $? -ne 0 ]; then
    echo "Failed to store OpenAI credentials in AWS Secrets Manager."
    exit 1
fi

echo ""
echo "✅ Secrets successfully configured in AWS Secrets Manager!"
echo ""
echo "You can now proceed with deploying the Docker image:"
echo "1. ./deploy_docker.sh"
echo ""
