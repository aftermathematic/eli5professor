#!/bin/bash

# Script to build and push the Twitter Bot Docker image to ECR

echo "Building and pushing Twitter Bot Docker image to ECR"
echo "==================================================="
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

# Get ECR repository URL
echo "Getting ECR repository URL..."
ECR_REPO=$(aws ecr describe-repositories --repository-names eli5-twitter-bot-dev --region eu-west-3 --query 'repositories[0].repositoryUri' --output text)

if [ -z "$ECR_REPO" ]; then
    echo "Failed to get ECR repository URL."
    echo "Please make sure the ECR repository has been created."
    exit 1
fi

echo "ECR Repository URL: $ECR_REPO"

# Get AWS region
AWS_REGION="eu-west-3"
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
echo "Building Docker image for Twitter Bot..."
echo "This will use the necessary dependencies including torch and transformers for the local model fallback."
docker build -t $ECR_REPO:twitter-bot -f Dockerfile.twitter-bot .

if [ $? -ne 0 ]; then
    echo "Failed to build Docker image."
    exit 1
fi

# Push image to ECR
echo ""
echo "Pushing Docker image to ECR..."
docker push $ECR_REPO:twitter-bot

if [ $? -ne 0 ]; then
    echo "Failed to push Docker image to ECR."
    exit 1
fi

echo ""
echo "✅ Docker image successfully built and pushed to ECR!"
echo ""
echo "Next steps:"
echo ""
echo "1. Update the App Runner service to use the new Docker image:"
echo "   aws apprunner update-service --service-arn <TWITTER_BOT_SERVICE_ARN> --source-configuration '{\"ImageRepository\":{\"ImageIdentifier\":\"$ECR_REPO:twitter-bot\",\"ImageRepositoryType\":\"ECR\",\"ImageConfiguration\":{\"Port\":\"8000\",\"RuntimeEnvironmentVariables\":{\"ENVIRONMENT\":\"dev\",\"TWITTER_API_KEY\":\"eli5-twitter-bot/twitter-credentials-dev:TWITTER_API_KEY\",\"TWITTER_API_SECRET\":\"eli5-twitter-bot/twitter-credentials-dev:TWITTER_API_SECRET\",\"TWITTER_ACCESS_TOKEN\":\"eli5-twitter-bot/twitter-credentials-dev:TWITTER_ACCESS_TOKEN\",\"TWITTER_ACCESS_TOKEN_SECRET\":\"eli5-twitter-bot/twitter-credentials-dev:TWITTER_ACCESS_TOKEN_SECRET\",\"TWITTER_BEARER_TOKEN\":\"eli5-twitter-bot/twitter-credentials-dev:TWITTER_BEARER_TOKEN\",\"TWITTER_ACCOUNT_HANDLE\":\"eli5-twitter-bot/twitter-credentials-dev:TWITTER_ACCOUNT_HANDLE\",\"TWITTER_USER_ID\":\"eli5-twitter-bot/twitter-credentials-dev:TWITTER_USER_ID\",\"OPENAI_API_KEY\":\"eli5-twitter-bot/openai-credentials-dev:OPENAI_API_KEY\"},\"StartCommand\":\"python src/main.py\"}}}'"
echo ""
