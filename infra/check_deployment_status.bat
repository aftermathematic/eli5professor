@echo off
echo ELI5 Discord Bot - Deployment Status Check
echo ========================================
echo.

echo Checking Terraform outputs...
echo.
terraform output

echo.
echo Checking App Runner services in AWS...
echo.
aws apprunner list-services --region eu-west-3 --query "ServiceSummaryList[?contains(ServiceName, 'eli5-discord-bot')].[ServiceName,Status,ServiceUrl]" --output table

echo.
echo Checking ECR repository...
echo.
aws ecr describe-images --repository-name eli5-discord-bot-dev --region eu-west-3 --query "imageDetails[0].[imageTags[0],imagePushedAt]" --output table

echo.
echo ========================================
echo Deployment Status Summary:
echo ========================================
echo.
echo 1. If App Runner services show "RUNNING" status, your deployment is successful
echo 2. If services show "OPERATION_IN_PROGRESS", they are still being created
echo 3. If there are errors, check the AWS Console for detailed logs
echo.
echo AWS Console Links:
echo - App Runner: https://console.aws.amazon.com/apprunner/home?region=eu-west-3
echo - Secrets Manager: https://console.aws.amazon.com/secretsmanager/home?region=eu-west-3
echo - ECR: https://console.aws.amazon.com/ecr/repositories?region=eu-west-3
echo.
pause
