# App Runner services for the ELI5 Twitter Bot
# This file creates App Runner services with a placeholder image
# The services will be updated to use the actual ECR image using the update_app_runner.sh script

# App Runner service for the Twitter bot
module "twitter_bot_service" {
  count = local.deploy_app_runner ? 1 : 0
  source           = "./modules/apprunner-service"
  service_name     = "${var.app_name}-twitter-bot-${var.environment}"
  # The image_identifier is not used since we're using a placeholder image in the module
  image_identifier = "${module.app_repository.repository_url}:latest"
  port             = 8000
  environment_variables = {
    ENVIRONMENT = var.environment
    # Reference secrets using the format ${SECRETS_MANAGER_SECRET_NAME}:${JSON_KEY}
    TWITTER_API_KEY             = "${aws_secretsmanager_secret.twitter_credentials.name}:TWITTER_API_KEY"
    TWITTER_API_SECRET          = "${aws_secretsmanager_secret.twitter_credentials.name}:TWITTER_API_SECRET"
    TWITTER_ACCESS_TOKEN        = "${aws_secretsmanager_secret.twitter_credentials.name}:TWITTER_ACCESS_TOKEN"
    TWITTER_ACCESS_TOKEN_SECRET = "${aws_secretsmanager_secret.twitter_credentials.name}:TWITTER_ACCESS_TOKEN_SECRET"
    TWITTER_BEARER_TOKEN        = "${aws_secretsmanager_secret.twitter_credentials.name}:TWITTER_BEARER_TOKEN"
    TWITTER_ACCOUNT_HANDLE      = "${aws_secretsmanager_secret.twitter_credentials.name}:TWITTER_ACCOUNT_HANDLE"
    TWITTER_USER_ID             = "${aws_secretsmanager_secret.twitter_credentials.name}:TWITTER_USER_ID"
    OPENAI_API_KEY              = "${aws_secretsmanager_secret.openai_credentials.name}:OPENAI_API_KEY"
  }
  tags = local.tags
}

# App Runner service for the API
module "api_service" {
  count = local.deploy_app_runner ? 1 : 0
  source           = "./modules/apprunner-service"
  service_name     = "${var.app_name}-api-${var.environment}"
  # The image_identifier is not used since we're using a placeholder image in the module
  image_identifier = "${module.app_repository.repository_url}:latest"
  port             = 8000
  environment_variables = {
    ENVIRONMENT = var.environment
    OPENAI_API_KEY = "${aws_secretsmanager_secret.openai_credentials.name}:OPENAI_API_KEY"
  }
  tags = local.tags
}

# Outputs for App Runner services
output "twitter_bot_service_url" {
  description = "URL of the App Runner Twitter bot service"
  value       = local.deploy_app_runner ? module.twitter_bot_service[0].service_url : "Not deployed"
}

output "twitter_bot_service_arn" {
  description = "ARN of the App Runner Twitter bot service"
  value       = local.deploy_app_runner ? module.twitter_bot_service[0].service_arn : "Not deployed"
}

output "twitter_bot_service_ecr_role_arn" {
  description = "ARN of the ECR access role for the Twitter bot service"
  value       = local.deploy_app_runner ? module.twitter_bot_service[0].ecr_access_role_arn : "Not deployed"
}

output "api_service_url" {
  description = "URL of the App Runner API service"
  value       = local.deploy_app_runner ? module.api_service[0].service_url : "Not deployed"
}

output "api_service_arn" {
  description = "ARN of the App Runner API service"
  value       = local.deploy_app_runner ? module.api_service[0].service_arn : "Not deployed"
}

output "api_service_ecr_role_arn" {
  description = "ARN of the ECR access role for the API service"
  value       = local.deploy_app_runner ? module.api_service[0].ecr_access_role_arn : "Not deployed"
}
