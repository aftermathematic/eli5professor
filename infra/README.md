# ELI5 Twitter Bot Infrastructure

This directory contains the Terraform configuration for deploying the ELI5 Twitter Bot infrastructure to AWS.

## Infrastructure Components

The infrastructure consists of the following components:

- **S3 Bucket**: Stores model artifacts and data
- **ECR Repository**: Stores Docker images for the application
- **Secrets Manager**: Stores Twitter and OpenAI API credentials
- **App Runner Services** or **Lambda Functions**: Runs the Twitter bot and API services

This project supports two deployment options:
1. **App Runner**: Docker-based deployment with App Runner services
2. **Lambda**: Serverless deployment with Lambda functions and API Gateway

## Prerequisites

Before deploying the infrastructure, you need:

1. **AWS CLI**: Install and configure the AWS CLI with valid credentials
2. **Terraform**: Install Terraform CLI (version >= 1.0.0)
3. **Docker**: Install Docker to build and push images
4. **IAM Permissions**: Your AWS user needs permissions to create and manage the required resources

## Deployment Steps

### Option 1: App Runner Deployment

The App Runner deployment process is split into three stages:

1. **Stage 1**: Deploy the base infrastructure (S3, ECR, Secrets Manager)
2. **Stage 2**: Build and push the Docker image to ECR
3. **Stage 3**: Deploy the App Runner services

### Option 2: Lambda Deployment

The Lambda deployment process is split into three stages:

1. **Stage 1**: Deploy the base infrastructure (S3, ECR, Secrets Manager)
2. **Stage 2**: Package and upload the Lambda functions to S3
3. **Stage 3**: Deploy the Lambda functions and API Gateway

### 1. Set Up IAM Permissions

The deployment requires specific IAM permissions. You can set these up using the provided script:

```bash
cd infra
./setup_permissions.sh
```

This script will:
- Create an IAM policy with the necessary permissions
- Attach the policy to your current AWS user

If you prefer to set up permissions manually, you can:
1. Create a policy using the `iam_policy.json` file
2. Attach the policy to your AWS user

### 2. Configure AWS Credentials

Ensure your AWS credentials are properly configured:

```bash
aws configure
```

Enter your AWS Access Key ID, Secret Access Key, default region (eu-west-3), and output format (json).

Alternatively, you can use the provided script:

```bash
./configure_aws.sh
```

### 3. Initialize Terraform

```bash
cd infra
terraform init
```

If you encounter issues with Terraform initialization, you can use the provided scripts to fix the issues:

**For _netrc file issues:**

**For Linux/macOS:**
```bash
./fix_terraform_init.sh
```

**For Windows:**
```
fix_terraform_init.bat
```
or
```
direct_provider_download.bat
```
or (PowerShell)
```powershell
.\fix_terraform_init.ps1
```

These scripts will:
1. Create a custom .terraformrc file to use a local provider mirror
2. Download the AWS provider manually
3. Initialize Terraform with the local provider

The `direct_provider_download.bat` script is a more direct approach that downloads the AWS provider directly to the Terraform plugins directory and runs terraform init with the -plugin-dir flag.

The PowerShell script `fix_terraform_init.ps1` is recommended for Windows users as it provides the most reliable solution.

This is useful when you encounter errors like:
```
Error while installing hashicorp/aws: releases.hashicorp.com: CreateFile C:\Users\username\_netrc: The filename, directory name, or volume label syntax is incorrect.
```

**For module installation issues:**

**For Linux/macOS:**
```bash
./download_modules.sh
```

**For Windows:**
```
download_modules.bat
```
or (PowerShell)
```powershell
.\download_modules.ps1
```

These scripts will:
1. Manually copy the module files to the .terraform/modules directory
2. Create a modules.json file to register the modules with Terraform
3. Allow you to run terraform init without downloading the modules again

This is useful when you encounter errors like:
```
Error: Module not installed
```

### 4. Deploy Base Infrastructure

Deploy the base infrastructure (S3, ECR, Secrets Manager):

```bash
terraform plan -var-file=dev.tfvars -out tfplan
terraform apply "tfplan"
```

### 5. Store Secrets in AWS Secrets Manager

After the base infrastructure is deployed, store your Twitter and OpenAI API credentials in AWS Secrets Manager:

```bash
# Store Twitter credentials
aws secretsmanager put-secret-value \
  --secret-id eli5-twitter-bot/twitter-credentials-dev \
  --secret-string '{
    "TWITTER_API_KEY": "your-api-key",
    "TWITTER_API_SECRET": "your-api-secret",
    "TWITTER_ACCESS_TOKEN": "your-access-token",
    "TWITTER_ACCESS_TOKEN_SECRET": "your-access-token-secret",
    "TWITTER_BEARER_TOKEN": "your-bearer-token",
    "TWITTER_ACCOUNT_HANDLE": "your-account-handle",
    "TWITTER_USER_ID": "your-user-id"
  }'

# Store OpenAI credentials
aws secretsmanager put-secret-value \
  --secret-id eli5-twitter-bot/openai-credentials-dev \
  --secret-string '{
    "OPENAI_API_KEY": "your-openai-api-key"
  }'
```

### 6. Build and Push Docker Image

Build and push the Docker image to ECR:

```bash
# Get the ECR repository URL from Terraform output
ECR_REPO=$(terraform output -raw ecr_repository_url)

# Login to ECR
aws ecr get-login-password --region eu-west-3 | docker login --username AWS --password-stdin $ECR_REPO

# Build and tag the Docker image
docker build -t $ECR_REPO:latest .

# Push the image to ECR
docker push $ECR_REPO:latest
```

Alternatively, you can use the provided script:

```bash
./deploy_docker.sh
```

### 7. Deploy App Runner Services

After the Docker image is pushed to ECR, deploy the App Runner services:

```bash
./deploy_app_runner.sh
```

This script will:
1. Check if the Docker image exists in ECR
2. Verify that the app_runner.tf file exists
3. Apply the Terraform configuration to create the App Runner services

The App Runner services are initially created with a public Amazon Linux image as a placeholder. This ensures that the services can be created successfully without requiring the Docker image to be available in ECR.

### 8. Update App Runner Services

After the App Runner services are deployed and the Docker image is pushed to ECR, update the services to use the actual Docker image:

```bash
./update_app_runner.sh
```

This script will:
1. Check if the Docker image exists in ECR
2. Get the App Runner service ARNs from Terraform output
3. Update the App Runner services to use the actual Docker image from ECR

This two-step approach ensures that the App Runner services are created successfully and then updated to use the actual Docker image.

## Accessing the Services

After deployment, you can access the services using the URLs provided in the Terraform output:

```bash
# Get the service URLs
terraform output twitter_bot_service_url
terraform output api_service_url
```

## Cleaning Up

To destroy the infrastructure when you're done:

```bash
terraform destroy -var-file=dev.tfvars
```

If you encounter issues with the destroy command, such as resources that can't be deleted because they're not empty (like ECR repositories with images), you can use the force cleanup script:

```bash
./force_cleanup.sh
```

This script will:
1. Delete all images in the ECR repository
2. Delete all objects in the S3 bucket
3. Delete App Runner services directly using the AWS CLI
4. Delete Lambda functions directly using the AWS CLI
5. Delete API Gateway resources directly using the AWS CLI
6. Run terraform destroy to clean up the remaining resources
7. Remove Terraform state files

This is useful when you need to start with a clean slate or when the normal terraform destroy command fails due to resource dependencies.

## Handling Existing Resources

If you encounter errors like:

```
Error: creating Secrets Manager Secret: InvalidRequestException: You can't create this secret because a secret with this name is already scheduled for deletion.
```

or

```
Error: creating ECR Repository: RepositoryAlreadyExistsException: The repository with name 'eli5-twitter-bot-dev' already exists in the registry
```

You have two options to handle these situations:

### Option 1: Wait for Resources to be Deleted

You can use the wait_for_deletion scripts to check for existing resources and wait for them to be deleted:

**For Linux/macOS:**
```bash
./wait_for_deletion.sh
```

**For Windows:**
```
wait_for_deletion.bat
```
or (PowerShell)
```powershell
.\wait_for_deletion.ps1
```

These scripts will:
1. Check if any resources already exist or are scheduled for deletion
2. Provide options to:
   - Wait for the resources to be deleted (may take up to 30 days for secrets)
   - Run the force_cleanup.sh script to clean up existing resources
   - Proceed with deployment anyway (may fail if resources still exist)

### Option 2: Force Delete Resources

If you need to immediately delete resources that are causing issues, you can use the force_delete_resources script:

**For PowerShell:**
```powershell
.\force_delete_resources.ps1
```

This script will:
1. Force delete AWS Secrets Manager secrets that are scheduled for deletion
2. Force delete ECR repositories that already exist
3. Provide a summary of the deletion results

This is particularly useful when you're redeploying the infrastructure and some resources from a previous deployment are still in the process of being deleted. The force delete option is faster than waiting for the normal deletion process to complete, which can take up to 30 days for secrets.

## Automated Deployment

For a more streamlined experience, you can use the main deployment script that will guide you through all the steps:

**For Linux/macOS:**
```bash
cd infra
./deploy.sh
```

**For Windows:**
```
cd infra
deploy_all.bat
```
or (PowerShell)
```powershell
cd infra
.\deploy_all.ps1
```

These scripts will:
1. Fix Terraform initialization issues automatically
2. Help you choose a deployment type (App Runner or Lambda)
3. Deploy the base infrastructure with Terraform
4. Guide you to configure secrets in AWS Secrets Manager
5. Deploy the application based on your chosen deployment type
6. Display the outputs with service URLs

### App Runner Deployment

If you choose the App Runner deployment option, the script will:
1. Build and push the Docker image to ECR
2. Guide you to deploy the App Runner services with:
   ```bash
   ./deploy_app_runner.sh
   ```
3. Guide you to update the App Runner services with:
   ```bash
   ./update_app_runner.sh
   ```

### Lambda Deployment

If you choose the Lambda deployment option, the script will:
1. Package and upload the Lambda functions to S3 with:
   ```bash
   ./package_lambda.sh
   ```
2. Deploy the Lambda functions and API Gateway with:
   ```bash
   ./deploy_lambda.sh
   ```

## Troubleshooting

### Permission Errors

If you encounter permission errors when deploying the infrastructure:

1. Make sure you've run the `setup_permissions.sh` script
2. Wait a few minutes for the permissions to propagate
3. If issues persist, check your AWS user's permissions in the AWS Console
4. You may need to add additional permissions depending on your AWS account configuration

### Invalid AWS Credentials

If you encounter errors related to invalid AWS credentials:

1. Verify your AWS credentials are correctly configured:
   ```bash
   aws configure list
   ```

2. Test AWS CLI access:
   ```bash
   aws s3 ls
   ```

3. If needed, update your credentials:
   ```bash
   aws configure
   ```

### App Runner Service Deployment Issues

If the App Runner services fail to deploy:

1. Check the service logs in the AWS Console
2. Verify the Docker image exists in ECR
3. Ensure the IAM roles have the necessary permissions
4. Check if your AWS account has App Runner service quotas that might be limiting deployments

### Lambda Function Deployment Issues

If the Lambda functions fail to deploy:

1. Check the CloudWatch Logs for the Lambda functions
2. Verify the Lambda packages exist in S3
3. Ensure the IAM roles have the necessary permissions
4. Check if your AWS account has Lambda service quotas that might be limiting deployments
5. Verify that the Lambda function handler matches the actual code structure

### API Gateway Issues

If the API Gateway is not working correctly:

1. Check the API Gateway logs in the AWS Console
2. Verify the Lambda function permissions allow API Gateway to invoke the function
3. Test the API Gateway endpoint with a tool like curl or Postman
4. Check the Lambda function logs for any errors when invoked by API Gateway
