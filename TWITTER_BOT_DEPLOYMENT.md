# Twitter Bot Deployment Guide

This guide explains how to test and deploy the Twitter Bot service.

## Prerequisites

- Docker installed for local testing
- AWS CLI installed and configured for AWS deployment
- Access to the AWS account where the API service is deployed

## Local Testing

Before deploying to AWS, it's recommended to test the Twitter Bot container locally:

1. **Test the Twitter Bot container locally**

   Run the following command to build and run the Twitter Bot container locally:

   ```bash
   ./test_twitter_bot_locally.sh
   ```

   This script will:
   - Build a Docker image using the Dockerfile.twitter-bot file
   - Run the container with the necessary volume mounts and environment variables
   - Display the logs to verify that the Twitter Bot is working correctly

   The container will run in interactive mode, so you can see the logs in real-time. Press Ctrl+C to stop the container.

## AWS Deployment

Once you've verified that the Twitter Bot is working correctly locally, you can deploy it to AWS:

1. **Build and push the Twitter Bot Docker image to ECR**

   Run the following command to build and push the Twitter Bot Docker image to ECR:

   ```bash
   ./build_and_push_twitter_bot.sh
   ```

   This script will:
   - Build a Docker image using the Dockerfile.twitter-bot file (with minimal dependencies)
   - Tag the image with the ECR repository URL and the "twitter-bot" tag
   - Push the image to ECR

2. **Update or create the Twitter Bot App Runner service**

   Run the following command to update or create the Twitter Bot App Runner service:

   ```bash
   ./update_twitter_bot_service.sh
   ```

   This script will:
   - Check if the Twitter Bot service already exists
   - If it doesn't exist, create a new App Runner service
   - If it exists, update the service to use the new Docker image
   - Configure the service with the necessary environment variables

3. **Verify the deployment**

   After the deployment is complete, you can verify that the Twitter Bot service is running by checking the AWS App Runner console or by running the following command:

   ```bash
   aws apprunner list-services --region eu-west-3
   ```

   You should see both the API service and the Twitter Bot service listed.

## Setting Up Credentials

Before deploying the Twitter Bot, you need to set up the necessary credentials:

1. **Create a .env.test file with your Twitter API credentials**

   ```bash
   # OpenAI API configuration
   OPENAI_API_KEY=your_openai_api_key_here
   OPENAI_MODEL=gpt-3.5-turbo

   # Twitter API configuration
   TWITTER_API_KEY=your_twitter_api_key_here
   TWITTER_API_SECRET=your_twitter_api_secret_here
   TWITTER_ACCESS_TOKEN=your_twitter_access_token_here
   TWITTER_ACCESS_TOKEN_SECRET=your_twitter_access_token_secret_here
   TWITTER_BEARER_TOKEN=your_twitter_bearer_token_here
   TWITTER_ACCOUNT_HANDLE=your_twitter_handle_here
   TWITTER_USER_ID=1930180450879729664

   # Model configuration
   USE_LOCAL_MODEL_FALLBACK=true
   USE_OPENAI=false

   # Dataset configuration
   DATASET_PATH=data/dataset.csv
   NUM_EXAMPLES=3

   # Environment
   ENVIRONMENT=development
   ```

   Replace the placeholder values with your actual Twitter API credentials and OpenAI API key.

## Troubleshooting

If you encounter any issues during the deployment, check the following:

1. **Docker image build failure**
   - Make sure Docker is installed and running
   - Check that the requirements.txt file exists and contains all the necessary dependencies
   - Check that the Dockerfile.twitter-bot file is correct

2. **ECR push failure**
   - Make sure you have the necessary permissions to push to the ECR repository
   - Check that the ECR repository exists
   - Check that you're logged in to ECR

3. **App Runner service creation/update failure**
   - Make sure you have the necessary permissions to create/update App Runner services
   - Check that the ECR access role exists
   - Check that the Docker image was successfully pushed to ECR

4. **Twitter Bot not working**
   - Check the App Runner service logs for any errors
   - Make sure the Twitter API credentials are correctly configured in the .env.test file
   - Check that the Twitter Bot service is running
   - Verify that your Twitter API credentials are valid and have the necessary permissions

## Monitoring

You can monitor the Twitter Bot service by checking the App Runner service logs in the AWS Console or by using the AWS CLI:

```bash
aws apprunner list-operations --service-arn <TWITTER_BOT_SERVICE_ARN> --region eu-west-3
```

Replace `<TWITTER_BOT_SERVICE_ARN>` with the ARN of the Twitter Bot service.
