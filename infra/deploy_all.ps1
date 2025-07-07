# PowerShell script for comprehensive deployment of ELI5 Discord Bot

Write-Host "ELI5 Discord Bot - Comprehensive Deployment (PowerShell)"
Write-Host "======================================================"
Write-Host ""
Write-Host "This script will guide you through the entire deployment process."
Write-Host ""

# Check if Terraform is installed
try {
    $terraformVersion = terraform --version
    Write-Host "Terraform is installed: $terraformVersion"
} catch {
    Write-Host "Terraform is not installed. Please install it first:"
    Write-Host "https://developer.hashicorp.com/terraform/downloads"
    exit 1
}

# Check if AWS CLI is installed
try {
    $awsVersion = aws --version
    Write-Host "AWS CLI is installed: $awsVersion"
} catch {
    Write-Host "AWS CLI is not installed. Please install it first:"
    Write-Host "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
}

# Step 1: Fix Terraform initialization issues
Write-Host ""
Write-Host "Step 1: Fix Terraform initialization issues"
Write-Host "-----------------------------------------"
Write-Host ""
Write-Host "Attempting to fix Terraform initialization issues..."
Write-Host ""

# Try PowerShell provider download
Write-Host "Running fix_terraform_init.ps1..."
& .\fix_terraform_init.ps1

# Check if initialization was successful
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Provider download failed. Trying download_modules.ps1..."
    & .\download_modules.ps1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Module download failed. Please try manually:"
        Write-Host "1. Delete the .terraform directory: Remove-Item -Recurse -Force .terraform"
        Write-Host "2. Delete the .terraform.lock.hcl file: Remove-Item -Force .terraform.lock.hcl"
        Write-Host "3. Run terraform init again"
        exit 1
    }
}

# Step 2: Choose deployment type
Write-Host ""
Write-Host "Step 2: Choose deployment type"
Write-Host "----------------------------"
Write-Host ""
Write-Host "Please choose a deployment type:"
Write-Host "1. App Runner (Docker-based)"
Write-Host "2. Lambda (Serverless)"
Write-Host ""
$deploymentType = Read-Host "Enter your choice (1 or 2)"

if ($deploymentType -eq "1") {
    $deploymentVar = "deployment_type=app_runner"
    Write-Host ""
    Write-Host "You selected App Runner deployment."
} elseif ($deploymentType -eq "2") {
    $deploymentVar = "deployment_type=lambda"
    Write-Host ""
    Write-Host "You selected Lambda deployment."
} else {
    Write-Host ""
    Write-Host "Invalid choice. Please enter 1 or 2."
    exit 1
}

# Step 3: Check for existing resources
Write-Host ""
Write-Host "Step 3: Check for existing resources"
Write-Host "--------------------------------"
Write-Host ""
Write-Host "Checking for existing resources..."
Write-Host ""

# Run the wait_for_deletion script
& .\wait_for_deletion.ps1

# Step 4: Deploy base infrastructure
Write-Host ""
Write-Host "Step 4: Deploy base infrastructure"
Write-Host "--------------------------------"
Write-Host ""
Write-Host "Deploying base infrastructure..."
Write-Host ""

# Run terraform plan
Write-Host "Running terraform plan..."
terraform plan -var-file=dev.tfvars -var "$deploymentVar" -target=module.model_bucket -target=aws_secretsmanager_secret.discord_credentials -target=aws_secretsmanager_secret.openai_credentials -out tfplan

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Terraform plan failed. Please check the error message above."
    exit 1
}

# Run terraform apply
Write-Host ""
Write-Host "Running terraform apply..."
terraform apply "tfplan"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Terraform apply failed. Please check the error message above."
    exit 1
}

# Step 4: Configure secrets
Write-Host ""
Write-Host "Step 4: Configure secrets"
Write-Host "-----------------------"
Write-Host ""
Write-Host "Please configure your Discord and OpenAI API credentials in AWS Secrets Manager."
Write-Host ""
Write-Host "1. Open the AWS Console: https://console.aws.amazon.com/secretsmanager/home"
Write-Host "2. Find the secrets 'eli5-discord-bot/discord-credentials-dev' and 'eli5-discord-bot/openai-credentials-dev'"
Write-Host "3. Update the secret values with your API credentials"
Write-Host ""
Read-Host "Press Enter when you have configured your secrets"

# Step 5: Deploy application
Write-Host ""
Write-Host "Step 5: Deploy application"
Write-Host "------------------------"
Write-Host ""

if ($deploymentType -eq "1") {
    Write-Host "Deploying App Runner services..."
    Write-Host ""
    
    # Build and push Docker image
    Write-Host "Building and pushing Docker image..."
    
    # Get the ECR repository URL from Terraform output
    $ecrRepo = terraform output -raw ecr_repository_url
    
    # Login to ECR
    Write-Host "Logging in to ECR..."
    Invoke-Expression -Command "aws ecr get-login-password --region eu-west-3 | docker login --username AWS --password-stdin $ecrRepo"
    
    # Build and tag the Docker image
    Write-Host "Building and tagging Docker image..."
    docker build -t "$ecrRepo`:latest" ..
    
    # Push the image to ECR
    Write-Host "Pushing Docker image to ECR..."
    docker push "$ecrRepo`:latest"
    
    # Deploy App Runner services
    Write-Host ""
    Write-Host "Deploying App Runner services..."
    terraform plan -var-file=dev.tfvars -var "$deploymentVar" -out tfplan
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Terraform plan failed. Please check the error message above."
        exit 1
    }
    
    terraform apply "tfplan"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Terraform apply failed. Please check the error message above."
        exit 1
    }
} else {
    Write-Host "Deploying Lambda functions..."
    Write-Host ""
    
    # Package Lambda functions
    Write-Host "Packaging Lambda functions..."
    & .\package_lambda.ps1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Lambda packaging failed. Please check the error message above."
        exit 1
    }
    
    # Deploy Lambda functions
    Write-Host ""
    Write-Host "Deploying Lambda functions..."
    terraform plan -var-file=dev.tfvars -var "$deploymentVar" -out tfplan
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Terraform plan failed. Please check the error message above."
        exit 1
    }
    
    terraform apply "tfplan"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Terraform apply failed. Please check the error message above."
        exit 1
    }
}

# Step 6: Display outputs
Write-Host ""
Write-Host "Step 6: Display outputs"
Write-Host "---------------------"
Write-Host ""
Write-Host "Displaying Terraform outputs..."
Write-Host ""
terraform output

Write-Host ""
Write-Host "✅ Deployment completed successfully!"
Write-Host ""
Write-Host "You can now access your services using the URLs above."
Write-Host ""
