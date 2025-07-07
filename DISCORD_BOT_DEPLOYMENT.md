# ELI5 Discord Bot - AWS Deployment Guide

## Overview

This guide explains how to deploy your updated ELI5 Discord Bot to AWS using the automated deployment scripts.

## Prerequisites

1. **AWS CLI** configured with your credentials
2. **Docker** installed and running
3. **Terraform** installed (>= 1.0.0)
4. **Discord Bot Token** and channel/server IDs
5. **OpenAI API Key** (optional, has local model fallback)

## Discord Bot Credentials

You'll need the following Discord credentials:

- `DISCORD_BOT_TOKEN` - Your Discord bot token
- `DISCORD_CHANNEL_ID` - The channel ID where the bot listens
- `DISCORD_SERVER_ID` - The Discord server (guild) ID
- `TARGET_USER_ID` - The bot's user ID (for mention detection)
- `DISCORD_WEBHOOK_URL` - Webhook URL for posting responses

## Deployment Steps

### 1. Navigate to Infrastructure Directory

```bash
cd infra
```

### 2. Run Deployment Script

**Windows (Command Prompt):**
```bash
deploy_all.bat
```

**Windows (PowerShell):**
```bash
.\deploy_all.ps1
```

### 3. Choose Deployment Type

When prompted, choose:
- **Option 1: App Runner** (Recommended for Discord bot)
- **Option 2: Lambda** (For API-only usage)

### 4. Configure Secrets

The script will pause and ask you to configure secrets in AWS Secrets Manager:

1. Open AWS Console: https://console.aws.amazon.com/secretsmanager/home
2. Find these secrets:
   - `eli5-discord-bot/discord-credentials-dev`
   - `eli5-discord-bot/openai-credentials-dev`

3. Update the Discord credentials secret with:
   ```json
   {
     "DISCORD_BOT_TOKEN": "your_bot_token_here",
     "DISCORD_CHANNEL_ID": "your_channel_id_here",
     "DISCORD_SERVER_ID": "your_server_id_here",
     "TARGET_USER_ID": "your_bot_user_id_here",
     "DISCORD_WEBHOOK_URL": "your_webhook_url_here"
   }
   ```

4. Update the OpenAI credentials secret with:
   ```json
   {
     "OPENAI_API_KEY": "your_openai_api_key_here"
   }
   ```

### 5. Complete Deployment

After configuring secrets, press Enter to continue. The script will:

1. Build and push Docker image to ECR
2. Deploy App Runner services
3. Display service URLs and endpoints

## What Gets Deployed

### App Runner Services

1. **Discord Bot Service** - Runs the Discord bot components
2. **API Service** - Hosts the ELI5 explanation API

### Infrastructure

1. **ECR Repository** - Stores Docker images
2. **S3 Bucket** - Stores model artifacts and data
3. **Secrets Manager** - Securely stores API credentials
4. **IAM Roles** - Provides necessary permissions

## Post-Deployment

### Testing the Deployment

1. **Check Service Status**: Visit the App Runner URLs provided in the output
2. **Test API**: Use the API service URL to test the `/explain` endpoint
3. **Test Discord Bot**: Send a message in Discord: `@yourbotname explain something #eli5`

### Monitoring

- **CloudWatch Logs**: Check App Runner service logs
- **MLflow Tracking**: Access MLflow UI if deployed
- **Health Checks**: Use the `/health` endpoint

## Troubleshooting

### Common Issues

1. **Terraform Init Fails**: The script automatically tries to fix this
2. **Docker Build Fails**: Ensure Docker is running
3. **Secrets Not Found**: Make sure you configured the secrets correctly
4. **Bot Not Responding**: Check Discord credentials and permissions

### Manual Fixes

If the automated script fails, you can run individual components:

```bash
# Fix Terraform initialization
.\fix_terraform_init.ps1

# Deploy just the Docker image
.\deploy_docker.sh

# Update App Runner services
.\update_app_runner.sh
```

## Configuration Files

- `dev.tfvars` - Deployment configuration (app name, region, etc.)
- `main.tf` - Core infrastructure resources
- `app_runner.tf` - App Runner service definitions

## Cleanup

To remove all deployed resources:

```bash
terraform destroy -var-file=dev.tfvars
```

## Support

If you encounter issues:

1. Check the deployment script output for error messages
2. Review AWS CloudWatch logs
3. Verify all prerequisites are installed
4. Ensure AWS credentials are properly configured

---

**Note**: The deployment uses AWS Free Tier resources where possible, but some charges may apply for ECR storage and App Runner usage.
