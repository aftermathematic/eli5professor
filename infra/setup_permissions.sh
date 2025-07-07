#!/bin/bash

# Script to set up the necessary IAM permissions for the ELI5 Twitter Bot project

echo "ELI5 Twitter Bot - IAM Permissions Setup"
echo "========================================"
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

# Get current user identity
echo ""
echo "Checking current AWS identity..."
aws sts get-caller-identity

if [ $? -ne 0 ]; then
    echo "Failed to get AWS identity. Please check your AWS credentials."
    exit 1
fi

# Get username from identity
USER_ARN=$(aws sts get-caller-identity --query "Arn" --output text)
USER_NAME=$(echo $USER_ARN | cut -d'/' -f2)

echo "Current user: $USER_NAME"

# Create policy
echo ""
echo "Creating IAM policy for ELI5 Twitter Bot..."
POLICY_NAME="ELI5TwitterBotPolicy"
POLICY_ARN=$(aws iam create-policy \
    --policy-name $POLICY_NAME \
    --policy-document file://iam_policy.json \
    --query "Policy.Arn" \
    --output text)

if [ $? -ne 0 ]; then
    echo "Failed to create IAM policy. Checking if it already exists..."
    POLICY_ARN=$(aws iam list-policies \
        --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" \
        --output text)
    
    if [ -z "$POLICY_ARN" ]; then
        echo "Could not find or create the policy. You may need to create it manually."
        echo "Use the AWS Management Console to create a policy using the iam_policy.json file."
        exit 1
    else
        echo "Policy already exists: $POLICY_ARN"
    fi
else
    echo "Policy created: $POLICY_ARN"
fi

# Attach policy to user
echo ""
echo "Attaching policy to user $USER_NAME..."
aws iam attach-user-policy \
    --user-name $USER_NAME \
    --policy-arn $POLICY_ARN

if [ $? -ne 0 ]; then
    echo "Failed to attach policy to user. You may need to do this manually."
    echo "Use the AWS Management Console to attach the policy '$POLICY_NAME' to your user."
    exit 1
fi

echo ""
echo "✅ IAM permissions set up successfully!"
echo ""
echo "You can now proceed with deploying the infrastructure:"
echo "1. terraform init"
echo "2. terraform plan -var-file=dev.tfvars -out=tfplan"
echo "3. terraform apply \"tfplan\""
echo ""
echo "Note: It may take a few minutes for the permissions to propagate."
echo "If you still encounter permission errors, wait a few minutes and try again."
echo ""
