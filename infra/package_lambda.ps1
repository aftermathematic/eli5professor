# PowerShell script to package Lambda functions and upload them to S3

Write-Host "ELI5 Twitter Bot - Package Lambda Functions (PowerShell)"
Write-Host "===================================================="
Write-Host ""
Write-Host "This script will package Lambda functions and upload them to S3."
Write-Host ""

# Check if AWS CLI is installed
try {
    $awsVersion = aws --version
    Write-Host "AWS CLI is installed: $awsVersion"
} catch {
    Write-Host "AWS CLI is not installed. Please install it first:"
    Write-Host "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
}

# Check if S3 bucket exists
Write-Host "Checking if S3 bucket exists..."
# Make sure we're in the infra directory to get the correct Terraform output
$currentDir = Get-Location
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir
$s3BucketName = terraform output -raw s3_bucket_id 2>$null
Set-Location $currentDir

if ([string]::IsNullOrEmpty($s3BucketName)) {
    Write-Host "S3 bucket name not found in Terraform outputs. Make sure you've deployed the base infrastructure first."
    Write-Host "Run the following commands to deploy the base infrastructure:"
    Write-Host "cd infra"
    Write-Host "terraform plan -var-file=dev.tfvars -target=module.model_bucket -out tfplan"
    Write-Host "terraform apply ""tfplan"""
    exit 1
}

Write-Host "S3 bucket name: $s3BucketName"

# Create a temporary directory for packaging
Write-Host "Creating temporary directory for packaging..."
$tempDir = Join-Path $env:TEMP "lambda_package"
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Write-Host "Temporary directory: $tempDir"

# Package the Twitter bot Lambda function
Write-Host ""
Write-Host "Packaging Twitter bot Lambda function..."
Write-Host "------------------------------------"

# Copy source files
Write-Host "Copying source files..."
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir
Copy-Item -Path "$rootDir\src\*" -Destination $tempDir -Recurse
Copy-Item -Path "$scriptDir\lambda_requirements\twitter_bot_requirements.txt" -Destination "$tempDir\requirements.txt"

# Install dependencies
Write-Host "Installing dependencies..."
Set-Location $tempDir
pip install -r requirements.txt -t . --no-cache-dir --upgrade

# Remove unnecessary files to reduce package size
Write-Host "Removing unnecessary files to reduce package size..."
# Remove tests directories
Get-ChildItem -Path $tempDir -Recurse -Directory -Filter "tests" | Remove-Item -Recurse -Force
Get-ChildItem -Path $tempDir -Recurse -Directory -Filter "test" | Remove-Item -Recurse -Force
# Remove documentation
Get-ChildItem -Path $tempDir -Recurse -Directory -Filter "docs" | Remove-Item -Recurse -Force
Get-ChildItem -Path $tempDir -Recurse -Directory -Filter "doc" | Remove-Item -Recurse -Force
# Remove examples
Get-ChildItem -Path $tempDir -Recurse -Directory -Filter "examples" | Remove-Item -Recurse -Force
# Remove __pycache__ directories
Get-ChildItem -Path $tempDir -Recurse -Directory -Filter "__pycache__" | Remove-Item -Recurse -Force
# Remove .pyc files
Get-ChildItem -Path $tempDir -Recurse -File -Filter "*.pyc" | Remove-Item -Force
# Remove .dist-info directories
Get-ChildItem -Path $tempDir -Recurse -Directory -Filter "*.dist-info" | Remove-Item -Recurse -Force
# Remove .egg-info directories
Get-ChildItem -Path $tempDir -Recurse -Directory -Filter "*.egg-info" | Remove-Item -Recurse -Force

# Create the zip file
Write-Host "Creating zip file..."
$twitterBotZipPath = "$tempDir\twitter_bot.zip"
Compress-Archive -Path "$tempDir\*" -DestinationPath $twitterBotZipPath -Force

# Upload to S3
Write-Host "Uploading to S3..."
aws s3 cp $twitterBotZipPath "s3://$s3BucketName/lambda/twitter_bot.zip"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to upload Twitter bot Lambda function to S3."
    exit 1
}

Write-Host "Twitter bot Lambda function uploaded to S3."

# Package the API Lambda function
Write-Host ""
Write-Host "Packaging API Lambda function..."
Write-Host "-----------------------------"

# Clean up the temporary directory
Write-Host "Cleaning up temporary directory..."
Remove-Item -Path "$tempDir\*" -Recurse -Force

# Copy source files
Write-Host "Copying source files..."
Copy-Item -Path "$rootDir\src\app.py" -Destination $tempDir
Copy-Item -Path "$rootDir\src\model_loader.py" -Destination $tempDir
Copy-Item -Path "$scriptDir\lambda_requirements\api_requirements.txt" -Destination "$tempDir\requirements.txt"

# Install dependencies
Write-Host "Installing dependencies..."
Set-Location $tempDir
pip install -r requirements.txt -t . --no-cache-dir --upgrade

# Remove unnecessary files to reduce package size
Write-Host "Removing unnecessary files to reduce package size..."
# Remove tests directories
Get-ChildItem -Path $tempDir -Recurse -Directory -Filter "tests" | Remove-Item -Recurse -Force
Get-ChildItem -Path $tempDir -Recurse -Directory -Filter "test" | Remove-Item -Recurse -Force
# Remove documentation
Get-ChildItem -Path $tempDir -Recurse -Directory -Filter "docs" | Remove-Item -Recurse -Force
Get-ChildItem -Path $tempDir -Recurse -Directory -Filter "doc" | Remove-Item -Recurse -Force
# Remove examples
Get-ChildItem -Path $tempDir -Recurse -Directory -Filter "examples" | Remove-Item -Recurse -Force
# Remove __pycache__ directories
Get-ChildItem -Path $tempDir -Recurse -Directory -Filter "__pycache__" | Remove-Item -Recurse -Force
# Remove .pyc files
Get-ChildItem -Path $tempDir -Recurse -File -Filter "*.pyc" | Remove-Item -Force
# Remove .dist-info directories
Get-ChildItem -Path $tempDir -Recurse -Directory -Filter "*.dist-info" | Remove-Item -Recurse -Force
# Remove .egg-info directories
Get-ChildItem -Path $tempDir -Recurse -Directory -Filter "*.egg-info" | Remove-Item -Recurse -Force

# Create the zip file
Write-Host "Creating zip file..."
$apiZipPath = "$tempDir\api.zip"
Compress-Archive -Path "$tempDir\*" -DestinationPath $apiZipPath -Force

# Upload to S3
Write-Host "Uploading to S3..."
aws s3 cp $apiZipPath "s3://$s3BucketName/lambda/api.zip"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to upload API Lambda function to S3."
    exit 1
}

Write-Host "API Lambda function uploaded to S3."

# Clean up
Write-Host ""
Write-Host "Cleaning up..."
Set-Location (Split-Path -Parent $MyInvocation.MyCommand.Path)
Remove-Item -Path $tempDir -Recurse -Force

Write-Host ""
Write-Host "✅ Lambda functions packaged and uploaded to S3 successfully!"
Write-Host ""
Write-Host "You can now deploy the Lambda functions with:"
Write-Host "terraform plan -var-file=dev.tfvars -var ""deployment_type=lambda"" -out tfplan"
Write-Host "terraform apply ""tfplan"""
Write-Host ""
