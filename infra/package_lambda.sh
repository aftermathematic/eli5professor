#!/bin/bash

# Script to package Lambda functions and upload them to S3

echo "ELI5 Twitter Bot - Lambda Packaging"
echo "=================================="
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
# Note: We don't check for the terraform.tfstate file directly as it might be stored remotely
# or in a different directory. Instead, we'll try to get the outputs directly.
echo "Checking if infrastructure has been deployed..."

# Get S3 bucket name from Terraform output
echo "Getting S3 bucket name from Terraform output..."
# Make sure we're in the script's directory to get the correct Terraform output
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_DIR="$(pwd)"
cd "$SCRIPT_DIR"
S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null)

# If s3_bucket_name doesn't exist, try s3_bucket_id
if [ -z "$S3_BUCKET" ]; then
    echo "s3_bucket_name not found, trying s3_bucket_id..."
    S3_BUCKET=$(terraform output -raw s3_bucket_id 2>/dev/null)
fi

# Return to the original directory
cd "$CURRENT_DIR"

if [ -z "$S3_BUCKET" ]; then
    echo "Failed to get S3 bucket name from Terraform output."
    echo "Please make sure the infrastructure has been deployed successfully."
    exit 1
fi

echo "S3 Bucket: $S3_BUCKET"

# Create temporary directory for packaging
echo ""
echo "Creating temporary directory for packaging..."
TEMP_DIR=$(mktemp -d)
echo "Temporary directory: $TEMP_DIR"

# Function to package and upload a Lambda function
package_and_upload() {
    local name=$1
    local src_dir=$2
    local handler=$3
    local s3_key=$4
    local requirements_file=$5

    echo ""
    echo "Packaging $name Lambda function..."
    
    # Create a directory for the Lambda package
    mkdir -p "$TEMP_DIR/$name"
    
    # Copy the source code to the temporary directory
    cp -r "$SCRIPT_DIR/../$src_dir"/* "$TEMP_DIR/$name/"
    
    # Copy the requirements file
    cp "$requirements_file" "$TEMP_DIR/$name/requirements.txt"
    
    # Install dependencies
    echo "Installing dependencies..."
    cd "$TEMP_DIR/$name"
    pip install -r requirements.txt -t . --no-cache-dir --upgrade
    
    # Create the zip file using PowerShell (since we're on Windows)
    echo "Creating zip file..."
    # Convert Unix paths to Windows paths
    WIN_TEMP_DIR=$(cygpath -w "$TEMP_DIR" 2>/dev/null || echo "$TEMP_DIR" | sed 's|/|\\\\|g')
    WIN_NAME=$name
    
    # Create the zip file using PowerShell
    powershell -Command "& { \
        Set-Location -Path \"$WIN_TEMP_DIR\\$WIN_NAME\"; \
        Compress-Archive -Path \"*\" -DestinationPath \"..\\$WIN_NAME.zip\" -Force \
    }"
    
    # Return to the original directory
    cd "$CURRENT_DIR"
    
    # Upload the zip file to S3
    echo "Uploading to S3..."
    aws s3 cp "$TEMP_DIR/$name.zip" "s3://$S3_BUCKET/$s3_key"
    
    # Return to the original directory
    cd "$CURRENT_DIR"
}

# Package and upload the Twitter bot Lambda function
package_and_upload "twitter_bot" "src" "main.lambda_handler" "lambda/twitter_bot.zip" "$SCRIPT_DIR/lambda_requirements/twitter_bot_requirements.txt"

# Package and upload the API Lambda function
package_and_upload "api" "src" "app.lambda_handler" "lambda/api.zip" "$SCRIPT_DIR/lambda_requirements/api_requirements.txt"

# Clean up
echo ""
echo "Cleaning up..."
rm -rf "$TEMP_DIR"

echo ""
echo "✅ Lambda functions packaged and uploaded successfully!"
echo ""
echo "You can now deploy the Lambda functions with Terraform:"
echo "terraform plan -var-file=dev.tfvars -out=tfplan"
echo "terraform apply \"tfplan\""
echo ""
