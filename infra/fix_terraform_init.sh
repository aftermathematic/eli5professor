#!/bin/bash

# Script to fix Terraform initialization issues related to _netrc file

echo "ELI5 Discord Bot - Fix Terraform Init"
echo "===================================="
echo ""
echo "This script will fix Terraform initialization issues related to the _netrc file."
echo ""

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "Terraform is not installed. Please install it first:"
    echo "https://developer.hashicorp.com/terraform/downloads"
    exit 1
fi

# Create a temporary directory for Terraform
echo "Creating a temporary directory for Terraform..."
TEMP_DIR=$(mktemp -d)
echo "Temporary directory: $TEMP_DIR"

# Create a .terraformrc file in the home directory
echo "Creating a .terraformrc file in the home directory..."
cat > ~/.terraformrc << EOF
provider_installation {
  filesystem_mirror {
    path    = "$TEMP_DIR/terraform-providers"
    include = ["registry.terraform.io/hashicorp/*"]
  }
  direct {
    exclude = ["registry.terraform.io/hashicorp/*"]
  }
}
EOF

echo ".terraformrc file created."

# Create the provider mirror directory
echo "Creating the provider mirror directory..."
mkdir -p "$TEMP_DIR/terraform-providers"

# Download the AWS provider manually
echo "Downloading the AWS provider manually..."
mkdir -p "$TEMP_DIR/terraform-providers/registry.terraform.io/hashicorp/aws/4.67.0/windows_amd64"
curl -L -o "$TEMP_DIR/terraform-providers/registry.terraform.io/hashicorp/aws/4.67.0/windows_amd64/terraform-provider-aws_v4.67.0_x5.zip" https://releases.hashicorp.com/terraform-provider-aws/4.67.0/terraform-provider-aws_4.67.0_windows_amd64.zip

echo "AWS provider downloaded."

# Initialize Terraform
echo ""
echo "Initializing Terraform..."
terraform init

# Check if initialization was successful
if [ $? -eq 0 ]; then
echo ""
echo "✅ Terraform initialization completed successfully!"
echo ""
echo "You can now proceed with the deployment:"
echo "1. terraform plan -var-file=dev.tfvars -out tfplan"
echo "2. terraform apply \"tfplan\""
echo ""
else
    echo ""
    echo "❌ Terraform initialization failed."
    echo ""
    echo "Please try the following:"
    echo "1. Delete the .terraform directory: rm -rf .terraform"
    echo "2. Delete the .terraform.lock.hcl file: rm -f .terraform.lock.hcl"
    echo "3. Try initializing Terraform again with the -plugin-dir flag:"
    echo "   terraform init -plugin-dir=$TEMP_DIR/terraform-providers"
    echo ""
fi
