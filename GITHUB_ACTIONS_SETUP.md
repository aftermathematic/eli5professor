# GitHub Actions Setup for ELI5 Discord Bot

This document explains how to configure GitHub Actions for automated deployment of your Discord bot to AWS.

## Required GitHub Secrets

To enable the CI/CD pipeline, you need to configure the following secrets in your GitHub repository:

### 1. Navigate to Repository Settings
1. Go to your GitHub repository: `https://github.com/aftermathematic/eli5professor`
2. Click on **Settings** tab
3. In the left sidebar, click **Secrets and variables** → **Actions**
4. Click **New repository secret** for each secret below

### 2. Required Secrets

#### AWS Credentials
- **`AWS_ACCESS_KEY_ID`**: Your AWS access key ID
- **`AWS_SECRET_ACCESS_KEY`**: Your AWS secret access key

**How to get these:**
1. Go to AWS IAM Console
2. Create a new user or use existing user with programmatic access
3. Attach policies: `AmazonEC2ContainerRegistryFullAccess`, `AWSAppRunnerFullAccess`
4. Generate access keys and copy them to GitHub secrets

## What Happens When You Push to Main Branch

### 1. **Testing Phase** (Always runs)
- ✅ Code checkout
- ✅ Python 3.10 setup
- ✅ Install dependencies
- ✅ Code linting with flake8
- ✅ Run test suite with pytest

### 2. **Build & Deploy Phase** (Only if tests pass)
- 🔐 Configure AWS credentials
- 🐳 Login to Amazon ECR
- 🏗️ Build Discord bot Docker image using `Dockerfile.bot`
- 📤 Push image to ECR with both commit SHA and `latest` tags
- 🚀 Trigger App Runner deployment
- ⏳ Wait for deployment completion
- ✅ Verify deployment status

## Deployment Flow

```
git push origin main
    ↓
GitHub Actions Triggered
    ↓
Run Tests & Linting
    ↓ (if tests pass)
Build Docker Image (Dockerfile.bot)
    ↓
Push to AWS ECR
    ↓
Trigger App Runner Deployment
    ↓
Discord Bot Updated with Latest Code
```

## Benefits of This Setup

1. **Automated Quality Assurance**: Every push is tested and linted
2. **Zero-Downtime Deployment**: App Runner handles rolling updates
3. **Consistent Builds**: Same Docker environment locally and in production
4. **Rollback Capability**: Each commit creates a tagged image for easy rollback
5. **Health Check Integration**: Uses your `discord_bot_with_health.py` for proper health monitoring

## Monitoring Deployments

### GitHub Actions
- View workflow runs at: `https://github.com/aftermathematic/eli5professor/actions`
- Each run shows detailed logs for debugging

### AWS App Runner
- Monitor service status in AWS Console
- View application logs in CloudWatch
- Check deployment history

## Troubleshooting

### Common Issues

1. **AWS Credentials Error**
   - Verify secrets are correctly set in GitHub
   - Ensure IAM user has required permissions

2. **ECR Push Fails**
   - Check if ECR repository exists
   - Verify repository name matches workflow configuration

3. **App Runner Deployment Fails**
   - Check App Runner service ARN is correct
   - Verify health check endpoint is responding

4. **Tests Fail**
   - Fix code issues locally first
   - Ensure all dependencies are in `requirements.txt`

### Manual Deployment (Fallback)
If GitHub Actions fails, you can still deploy manually:
```bash
# Build and push
docker build -f Dockerfile.bot -t 335561736978.dkr.ecr.eu-west-3.amazonaws.com/eli5-discord-bot-bot-dev:latest .
docker push 335561736978.dkr.ecr.eu-west-3.amazonaws.com/eli5-discord-bot-bot-dev:latest

# Trigger deployment
aws apprunner start-deployment --service-arn arn:aws:apprunner:eu-west-3:335561736978:service/eli5-discord-bot-discord-bot-dev/a5592aca377042f5805c7595bd63a2a8
```

## Next Steps

1. Configure the required GitHub secrets
2. Push a small change to test the pipeline
3. Monitor the deployment in GitHub Actions and AWS Console
4. Your Discord bot will automatically update with your latest code!
