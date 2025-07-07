#!/bin/bash

# Script to update the Twitter Bot App Runner service to use the new Docker image

echo "Updating Twitter Bot App Runner service"
echo "======================================"
echo ""

# Load environment variables from .env.test
if [ -f .env.test ]; then
    echo "Loading environment variables from .env.test..."
    export $(grep -v '^#' .env.test | xargs)
else
    echo "Error: .env.test file not found."
    echo "Please create a .env.test file with the necessary environment variables."
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first:"
    echo "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
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

# Get Twitter Bot service ARN
echo "Getting Twitter Bot service ARN..."
TWITTER_BOT_SERVICE_ARN=$(aws apprunner list-services --region $AWS_REGION --query "ServiceSummaryList[?ServiceName=='eli5-twitter-bot-twitter-bot-dev'].ServiceArn" --output text)

if [ -z "$TWITTER_BOT_SERVICE_ARN" ]; then
    echo "Twitter Bot service not found. Creating a new service..."
    
    # Get ECR access role ARN
    echo "Getting ECR access role ARN..."
    ECR_ACCESS_ROLE_ARN=$(aws iam list-roles --query "Roles[?RoleName=='eli5-twitter-bot-twitter-bot-dev-ecr-access-role'].Arn" --output text)
    
    if [ -z "$ECR_ACCESS_ROLE_ARN" ]; then
        echo "ECR access role not found. Please make sure the role has been created."
        exit 1
    fi
    
    echo "ECR Access Role ARN: $ECR_ACCESS_ROLE_ARN"
    
    # Create App Runner service
    echo "Creating App Runner service..."
    aws apprunner create-service \
        --service-name eli5-twitter-bot-twitter-bot-dev \
        --source-configuration "{
            \"AuthenticationConfiguration\": {
                \"AccessRoleArn\": \"$ECR_ACCESS_ROLE_ARN\"
            },
            \"ImageRepository\": {
                \"ImageIdentifier\": \"$ECR_REPO:twitter-bot\",
                \"ImageRepositoryType\": \"ECR\",
                \"ImageConfiguration\": {
                    \"Port\": \"8000\",
                    \"RuntimeEnvironmentVariables\": {
                        \"ENVIRONMENT\": \"dev\",
                        \"TWITTER_API_KEY\": \"${TWITTER_API_KEY}\",
                        \"TWITTER_API_SECRET\": \"${TWITTER_API_SECRET}\",
                        \"TWITTER_ACCESS_TOKEN\": \"${TWITTER_ACCESS_TOKEN}\",
                        \"TWITTER_ACCESS_TOKEN_SECRET\": \"${TWITTER_ACCESS_TOKEN_SECRET}\",
                        \"TWITTER_BEARER_TOKEN\": \"${TWITTER_BEARER_TOKEN}\",
                        \"TWITTER_ACCOUNT_HANDLE\": \"${TWITTER_ACCOUNT_HANDLE}\",
                        \"TWITTER_USER_ID\": \"1930180450879729664\",
                        \"OPENAI_API_KEY\": \"${OPENAI_API_KEY}\"
                    },
                    \"StartCommand\": \"python src/main.py\"
                }
            },
            \"AutoDeploymentsEnabled\": true
        }" \
        --instance-configuration "{
            \"Cpu\": \"1024\",
            \"Memory\": \"2048\"
        }" \
        --tags Key=Name,Value=eli5-twitter-bot Key=Environment,Value=dev Key=ManagedBy,Value=Terraform \
        --region $AWS_REGION
    
    if [ $? -ne 0 ]; then
        echo "Failed to create App Runner service."
        exit 1
    fi
    
    echo "App Runner service created successfully."
else
    echo "Twitter Bot Service ARN: $TWITTER_BOT_SERVICE_ARN"
    
    # Update App Runner service
    echo "Updating App Runner service..."
    aws apprunner update-service \
        --service-arn "$TWITTER_BOT_SERVICE_ARN" \
        --source-configuration "{
            \"ImageRepository\": {
                \"ImageIdentifier\": \"$ECR_REPO:twitter-bot\",
                \"ImageRepositoryType\": \"ECR\",
                \"ImageConfiguration\": {
                    \"Port\": \"8000\",
                    \"RuntimeEnvironmentVariables\": {
                        \"ENVIRONMENT\": \"dev\",
                        \"TWITTER_API_KEY\": \"${TWITTER_API_KEY}\",
                        \"TWITTER_API_SECRET\": \"${TWITTER_API_SECRET}\",
                        \"TWITTER_ACCESS_TOKEN\": \"${TWITTER_ACCESS_TOKEN}\",
                        \"TWITTER_ACCESS_TOKEN_SECRET\": \"${TWITTER_ACCESS_TOKEN_SECRET}\",
                        \"TWITTER_BEARER_TOKEN\": \"${TWITTER_BEARER_TOKEN}\",
                        \"TWITTER_ACCOUNT_HANDLE\": \"${TWITTER_ACCOUNT_HANDLE}\",
                        \"TWITTER_USER_ID\": \"1930180450879729664\",
                        \"OPENAI_API_KEY\": \"${OPENAI_API_KEY}\"
                    },
                    \"StartCommand\": \"python src/main.py\"
                }
            },
            \"AutoDeploymentsEnabled\": true
        }" \
        --region $AWS_REGION
    
    if [ $? -ne 0 ]; then
        echo "Failed to update App Runner service."
        exit 1
    fi
    
    echo "App Runner service updated successfully."
fi

echo ""
echo "✅ Twitter Bot App Runner service updated successfully!"
echo ""
echo "You can now check the status of the service:"
echo "aws apprunner describe-service --service-arn $TWITTER_BOT_SERVICE_ARN --region $AWS_REGION"
echo ""
