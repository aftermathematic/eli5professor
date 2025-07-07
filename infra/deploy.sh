#!/bin/bash

# Main deployment script for the ELI5 Twitter Bot project

echo "ELI5 Twitter Bot - Deployment Script"
echo "==================================="
echo ""
echo "This script will guide you through the deployment process for the ELI5 Twitter Bot."
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

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install it first:"
    echo "https://docs.docker.com/get-docker/"
    exit 1
fi

# Make sure all scripts are executable
chmod +x configure_aws.sh configure_secrets.sh deploy_docker.sh setup_permissions.sh

# Step 1: Set up IAM permissions
echo ""
echo "Step 1: Set up IAM permissions"
echo "-----------------------------"
read -p "Do you want to set up IAM permissions? (y/n): " setup_permissions
if [[ $setup_permissions == "y" || $setup_permissions == "Y" ]]; then
    ./setup_permissions.sh
    if [ $? -ne 0 ]; then
        echo "Failed to set up IAM permissions. Exiting."
        exit 1
    fi
else
    echo "Skipping IAM permissions setup."
    echo "Make sure your AWS user has the necessary permissions."
fi

# Step 2: Configure AWS credentials
echo ""
echo "Step 2: Configure AWS credentials"
echo "--------------------------------"
read -p "Do you want to configure AWS credentials? (y/n): " configure_aws
if [[ $configure_aws == "y" || $configure_aws == "Y" ]]; then
    ./configure_aws.sh
    if [ $? -ne 0 ]; then
        echo "Failed to configure AWS credentials. Exiting."
        exit 1
    fi
else
    echo "Skipping AWS credentials configuration."
    echo "Make sure your AWS credentials are properly configured."
fi

# Step 3: Check for existing resources
echo ""
echo "Step 3: Check for existing resources"
echo "----------------------------"
read -p "Do you want to check for existing resources? (y/n): " check_resources
if [[ $check_resources == "y" || $check_resources == "Y" ]]; then
    echo "Checking for existing resources..."
    chmod +x ./wait_for_deletion.sh
    ./wait_for_deletion.sh
    if [ $? -ne 0 ]; then
        echo "Failed to check for existing resources. Exiting."
        exit 1
    fi
else
    echo "Skipping resource check."
    echo "Note that deployment may fail if resources already exist."
fi

# Step 4: Deploy infrastructure
echo ""
echo "Step 4: Deploy infrastructure"
echo "----------------------------"
read -p "Do you want to deploy the infrastructure? (y/n): " deploy_infra
if [[ $deploy_infra == "y" || $deploy_infra == "Y" ]]; then
    echo "Initializing Terraform..."
    terraform init
    if [ $? -ne 0 ]; then
        echo "Failed to initialize Terraform. Exiting."
        exit 1
    fi
    
    echo "Planning Terraform deployment..."
    
    # Set the deployment type based on the user's choice
    if [[ $deployment_method == "1" ]]; then
        # App Runner deployment
        echo "Using App Runner deployment type..."
        terraform plan -var-file=dev.tfvars -var="deployment_type=app_runner" -out tfplan
    elif [[ $deployment_method == "2" ]]; then
        # Lambda deployment
        echo "Using Lambda deployment type..."
        terraform plan -var-file=dev.tfvars -var="deployment_type=lambda" -out tfplan
    else
        # Default to the value in dev.tfvars
        terraform plan -var-file=dev.tfvars -out tfplan
    fi
    
    if [ $? -ne 0 ]; then
        echo "Failed to plan Terraform deployment. Exiting."
        exit 1
    fi
    
    echo "Applying Terraform deployment..."
    terraform apply "tfplan"
    if [ $? -ne 0 ]; then
        echo "Failed to apply Terraform deployment. Exiting."
        exit 1
    fi
else
    echo "Skipping infrastructure deployment."
    echo "Make sure the infrastructure is already deployed."
fi

# Step 4: Configure secrets
echo ""
echo "Step 4: Configure secrets"
echo "-----------------------"
read -p "Do you want to configure secrets in AWS Secrets Manager? (y/n): " configure_secrets
if [[ $configure_secrets == "y" || $configure_secrets == "Y" ]]; then
    ./configure_secrets.sh
    if [ $? -ne 0 ]; then
        echo "Failed to configure secrets. Exiting."
        exit 1
    fi
else
    echo "Skipping secrets configuration."
    echo "Make sure your secrets are already configured in AWS Secrets Manager."
fi

# Step 5: Choose deployment method
echo ""
echo "Step 5: Choose deployment method"
echo "-----------------------------"
echo "1. App Runner (Docker-based deployment)"
echo "2. Lambda (Serverless deployment)"
read -p "Choose deployment method (1/2): " deployment_method

if [[ $deployment_method == "1" ]]; then
    # Deploy with App Runner
    echo ""
    echo "Step 5a: Deploy Docker image"
    echo "-------------------------"
    read -p "Do you want to build and deploy the Docker image? (y/n): " deploy_docker
    if [[ $deploy_docker == "y" || $deploy_docker == "Y" ]]; then
        ./deploy_docker.sh
        if [ $? -ne 0 ]; then
            echo "Failed to deploy Docker image. Exiting."
            exit 1
        fi
    else
        echo "Skipping Docker image deployment."
        echo "Make sure your Docker image is already deployed to ECR."
    fi
elif [[ $deployment_method == "2" ]]; then
    # Deploy with Lambda
    echo ""
    echo "Step 5a: Package Lambda functions"
    echo "-----------------------------"
    read -p "Do you want to package and upload the Lambda functions? (y/n): " package_lambda
    if [[ $package_lambda == "y" || $package_lambda == "Y" ]]; then
        ./package_lambda.sh
        if [ $? -ne 0 ]; then
            echo "Failed to package Lambda functions. Exiting."
            exit 1
        fi
    else
        echo "Skipping Lambda packaging."
        echo "Make sure your Lambda packages are already uploaded to S3."
    fi
    
    echo ""
    echo "Step 5b: Deploy Lambda functions"
    echo "-----------------------------"
    read -p "Do you want to deploy the Lambda functions? (y/n): " deploy_lambda
    if [[ $deploy_lambda == "y" || $deploy_lambda == "Y" ]]; then
        ./deploy_lambda.sh
        if [ $? -ne 0 ]; then
            echo "Failed to deploy Lambda functions. Exiting."
            exit 1
        fi
    else
        echo "Skipping Lambda deployment."
        echo "You can deploy the Lambda functions later with:"
        echo "./deploy_lambda.sh"
    fi
else
    echo "Invalid choice. Exiting."
    exit 1
fi

# Deployment complete
echo ""
echo "✅ Base infrastructure deployment completed!"
echo ""
echo "ECR Repository URL: $(terraform output -raw ecr_repository_url 2>/dev/null || echo "Not available")"
echo "S3 Bucket Name: $(terraform output -raw s3_bucket_name 2>/dev/null || echo "Not available")"
echo ""

if [[ $deployment_method == "1" ]]; then
    # App Runner deployment
    echo "Next steps for App Runner deployment:"
    echo ""
    echo "1. Deploy the App Runner services:"
    echo "   ./deploy_app_runner.sh"
    echo ""
    echo "2. After the App Runner services are deployed, update them to use the actual Docker image:"
    echo "   ./update_app_runner.sh"
    echo ""
elif [[ $deployment_method == "2" ]]; then
    # Lambda deployment
    echo "Next steps for Lambda deployment:"
    echo ""
    echo "1. If you haven't packaged the Lambda functions yet:"
    echo "   ./package_lambda.sh"
    echo ""
    echo "2. If you haven't deployed the Lambda functions yet:"
    echo "   ./deploy_lambda.sh"
    echo ""
    echo "Twitter Bot Lambda Function: $(terraform output -raw twitter_bot_lambda_function_name 2>/dev/null || echo "Not available")"
    echo "API Gateway URL: $(terraform output -raw api_gateway_url 2>/dev/null || echo "Not available")"
    echo ""
fi

echo "For more information, please refer to the README.md file."
echo ""
