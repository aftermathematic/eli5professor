#!/bin/bash

# Script to configure secrets in AWS Secrets Manager for the ELI5 Discord Bot project

echo "ELI5 Discord Bot - Secrets Configuration"
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
    APP_NAME="eli5-discord-bot"  # Default app name
    ENVIRONMENT="dev"  # Default environment
fi

echo "App Name: $APP_NAME"
echo "Environment: $ENVIRONMENT"

# Secret names
DISCORD_SECRET_NAME="$APP_NAME/discord-credentials-$ENVIRONMENT"
OPENAI_SECRET_NAME="$APP_NAME/openai-credentials-$ENVIRONMENT"

echo ""
echo "Configuring Discord Bot credentials..."
echo "Please enter your Discord Bot credentials:"

# Prompt for Discord Bot credentials
read -p "Discord Bot Token: " DISCORD_BOT_TOKEN
read -p "Discord Guild ID: " DISCORD_GUILD_ID
read -p "Discord Channel ID: " DISCORD_CHANNEL_ID
read -p "Target User ID (bot user ID): " TARGET_USER_ID

# Create Discord credentials JSON
DISCORD_SECRET_VALUE="{
  \"DISCORD_BOT_TOKEN\": \"$DISCORD_BOT_TOKEN\",
  \"DISCORD_GUILD_ID\": \"$DISCORD_GUILD_ID\",
  \"DISCORD_CHANNEL_ID\": \"$DISCORD_CHANNEL_ID\",
  \"TARGET_USER_ID\": \"$TARGET_USER_ID\"
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

echo "Storing Discord credentials..."
# Try to update existing secret first, if it fails, create a new one
aws secretsmanager put-secret-value \
  --secret-id "$DISCORD_SECRET_NAME" \
  --secret-string "$DISCORD_SECRET_VALUE" \
  --region "$AWS_REGION" 2>/dev/null

if [ $? -ne 0 ]; then
    echo "Secret doesn't exist, creating new Discord credentials secret..."
    aws secretsmanager create-secret \
      --name "$DISCORD_SECRET_NAME" \
      --description "Discord Bot credentials for ELI5 bot" \
      --secret-string "$DISCORD_SECRET_VALUE" \
      --region "$AWS_REGION"
    
    if [ $? -ne 0 ]; then
        echo "Failed to create Discord credentials in AWS Secrets Manager."
        exit 1
    fi
else
    echo "Discord credentials updated successfully."
fi

echo "Storing OpenAI credentials..."
# Try to update existing secret first, if it fails, create a new one
aws secretsmanager put-secret-value \
  --secret-id "$OPENAI_SECRET_NAME" \
  --secret-string "$OPENAI_SECRET_VALUE" \
  --region "$AWS_REGION" 2>/dev/null

if [ $? -ne 0 ]; then
    echo "Secret doesn't exist, creating new OpenAI credentials secret..."
    aws secretsmanager create-secret \
      --name "$OPENAI_SECRET_NAME" \
      --description "OpenAI API credentials for ELI5 bot" \
      --secret-string "$OPENAI_SECRET_VALUE" \
      --region "$AWS_REGION"
    
    if [ $? -ne 0 ]; then
        echo "Failed to create OpenAI credentials in AWS Secrets Manager."
        exit 1
    fi
else
    echo "OpenAI credentials updated successfully."
fi

echo ""
echo "✅ Secrets successfully configured in AWS Secrets Manager!"
echo ""
echo "You can now proceed with deploying the Docker image:"
echo "1. ./deploy_docker.sh"
echo ""
