#!/bin/bash

# Script to manually download Terraform modules

echo "ELI5 Twitter Bot - Download Terraform Modules"
echo "==========================================="
echo ""
echo "This script will manually download Terraform modules to fix initialization issues."
echo ""

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "Terraform is not installed. Please install it first:"
    echo "https://developer.hashicorp.com/terraform/downloads"
    exit 1
fi

# Create the modules directory structure
echo "Creating modules directory structure..."
mkdir -p .terraform/modules

# Create a temporary directory for downloading modules
echo "Creating a temporary directory for downloading modules..."
TEMP_DIR=$(mktemp -d)
echo "Temporary directory: $TEMP_DIR"

# Function to download and extract a module
download_module() {
    local module_name=$1
    local module_source=$2
    local module_dir=".terraform/modules/$module_name"
    
    echo ""
    echo "Downloading module: $module_name"
    echo "Source: $module_source"
    
    # Create the module directory
    mkdir -p "$module_dir"
    
    # Copy the module files
    cp -r "$module_source"/* "$module_dir/"
    
    echo "Module $module_name downloaded to $module_dir"
}

# Download the modules
download_module "model_bucket" "modules/s3-bucket"
download_module "app_repository" "modules/ecr-repository"
download_module "twitter_bot_service" "modules/apprunner-service"
download_module "api_service" "modules/apprunner-service"
download_module "twitter_bot_lambda" "modules/lambda-function"
download_module "api_lambda" "modules/lambda-function"

# Create a modules.json file
echo "Creating modules.json file..."
cat > .terraform/modules/modules.json << EOF
{
  "Modules": [
    {
      "Key": "model_bucket",
      "Source": "./modules/s3-bucket",
      "Dir": "modules/s3-bucket"
    },
    {
      "Key": "app_repository",
      "Source": "./modules/ecr-repository",
      "Dir": "modules/ecr-repository"
    },
    {
      "Key": "twitter_bot_service",
      "Source": "./modules/apprunner-service",
      "Dir": "modules/apprunner-service"
    },
    {
      "Key": "api_service",
      "Source": "./modules/apprunner-service",
      "Dir": "modules/apprunner-service"
    },
    {
      "Key": "twitter_bot_lambda",
      "Source": "./modules/lambda-function",
      "Dir": "modules/lambda-function"
    },
    {
      "Key": "api_lambda",
      "Source": "./modules/lambda-function",
      "Dir": "modules/lambda-function"
    }
  ]
}
EOF

echo ""
echo "✅ Terraform modules downloaded successfully!"
echo ""
echo "Now try running terraform init again:"
echo "terraform init"
echo ""
