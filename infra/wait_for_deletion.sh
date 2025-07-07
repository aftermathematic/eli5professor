#!/bin/bash

# Script to wait for AWS resources to be deleted

echo "ELI5 Twitter Bot - Wait for Resource Deletion"
echo "==========================================="
echo ""
echo "This script will wait for AWS resources to be deleted before proceeding with deployment."
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first:"
    echo "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Get AWS region
AWS_REGION=$(aws configure get region)
if [ -z "$AWS_REGION" ]; then
    AWS_REGION="eu-west-3"  # Default region
fi
echo "AWS Region: $AWS_REGION"

# Function to check if a secret exists and is scheduled for deletion
check_secret_deletion() {
    local secret_name=$1
    
    echo "Checking if secret $secret_name is scheduled for deletion..."
    
    if aws secretsmanager describe-secret --secret-id "$secret_name" --region "$AWS_REGION" &> /dev/null; then
        echo "Secret $secret_name exists."
        
        # Check if it's scheduled for deletion
        local deleted_date=$(aws secretsmanager describe-secret --secret-id "$secret_name" --region "$AWS_REGION" --query "DeletedDate" --output text)
        
        if [ "$deleted_date" != "None" ]; then
            echo "Secret $secret_name is scheduled for deletion."
            return 0  # true
        else
            echo "Secret $secret_name is not scheduled for deletion."
            return 1  # false
        fi
    else
        echo "Secret $secret_name does not exist or cannot be accessed."
        return 1  # false
    fi
}

# Function to check if an ECR repository exists
check_ecr_repository() {
    local repository_name=$1
    
    echo "Checking if ECR repository $repository_name exists..."
    
    if aws ecr describe-repositories --repository-names "$repository_name" --region "$AWS_REGION" &> /dev/null; then
        echo "ECR repository $repository_name exists."
        return 0  # true
    else
        echo "ECR repository $repository_name does not exist or cannot be accessed."
        return 1  # false
    fi
}

# Function to wait for a secret to be deleted
wait_for_secret_deletion() {
    local secret_name=$1
    local timeout_seconds=${2:-600}
    
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout_seconds))
    
    while [ $(date +%s) -lt $end_time ]; do
        if aws secretsmanager describe-secret --secret-id "$secret_name" --region "$AWS_REGION" &> /dev/null; then
            local deleted_date=$(aws secretsmanager describe-secret --secret-id "$secret_name" --region "$AWS_REGION" --query "DeletedDate" --output text)
            
            if [ "$deleted_date" != "None" ]; then
                echo "Secret $secret_name is still scheduled for deletion. Waiting..."
                sleep 30
            else
                echo "Secret $secret_name is no longer scheduled for deletion."
                return 0  # true
            fi
        else
            echo "Secret $secret_name no longer exists or cannot be accessed. Deletion complete."
            return 0  # true
        fi
    done
    
    echo "Timeout waiting for secret $secret_name to be deleted."
    return 1  # false
}

# Check for secrets scheduled for deletion
TWITTER_SECRET_NAME="eli5-twitter-bot/twitter-credentials-dev"
OPENAI_SECRET_NAME="eli5-twitter-bot/openai-credentials-dev"
ECR_REPOSITORY_NAME="eli5-twitter-bot-dev"

check_secret_deletion "$TWITTER_SECRET_NAME"
TWITTER_DELETING=$?

check_secret_deletion "$OPENAI_SECRET_NAME"
OPENAI_DELETING=$?

check_ecr_repository "$ECR_REPOSITORY_NAME"
ECR_EXISTS=$?

# If any resources are scheduled for deletion, ask the user what to do
if [ $TWITTER_DELETING -eq 0 ] || [ $OPENAI_DELETING -eq 0 ] || [ $ECR_EXISTS -eq 0 ]; then
    echo ""
    echo "Some resources already exist or are scheduled for deletion."
    echo "You have the following options:"
    echo "1. Wait for the resources to be deleted (may take up to 30 days for secrets)"
    echo "2. Run the force_cleanup.sh script to clean up existing resources"
    echo "3. Proceed with deployment anyway (may fail if resources still exist)"
    echo ""
    read -p "Enter your choice (1, 2, or 3): " CHOICE
    
    if [ "$CHOICE" = "1" ]; then
        echo ""
        echo "Waiting for resources to be deleted..."
        
        if [ $TWITTER_DELETING -eq 0 ]; then
            echo ""
            echo "Waiting for Twitter secret to be deleted..."
            echo "This may take a long time (up to 30 days)."
            echo "Press Ctrl+C to cancel."
            
            wait_for_secret_deletion "$TWITTER_SECRET_NAME"
            if [ $? -ne 0 ]; then
                echo "Failed to wait for Twitter secret deletion. You may need to wait longer or use the force_cleanup.sh script."
            fi
        fi
        
        if [ $OPENAI_DELETING -eq 0 ]; then
            echo ""
            echo "Waiting for OpenAI secret to be deleted..."
            echo "This may take a long time (up to 30 days)."
            echo "Press Ctrl+C to cancel."
            
            wait_for_secret_deletion "$OPENAI_SECRET_NAME"
            if [ $? -ne 0 ]; then
                echo "Failed to wait for OpenAI secret deletion. You may need to wait longer or use the force_cleanup.sh script."
            fi
        fi
        
        echo ""
        echo "Resource deletion check complete."
        echo "You can now proceed with deployment."
        echo ""
    elif [ "$CHOICE" = "2" ]; then
        echo ""
        echo "Running force_cleanup.sh script..."
        
        chmod +x ./force_cleanup.sh
        ./force_cleanup.sh
        
        echo ""
        echo "Force cleanup complete."
        echo "You can now proceed with deployment."
        echo ""
    else
        echo ""
        echo "Proceeding with deployment anyway."
        echo "Note that deployment may fail if resources still exist."
        echo ""
    fi
else
    echo ""
    echo "No resources are scheduled for deletion."
    echo "You can proceed with deployment."
    echo ""
fi

echo "Script completed."
echo ""
