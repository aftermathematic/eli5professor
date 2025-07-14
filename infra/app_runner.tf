# App Runner services for the ELI5 Discord Bot
# This file creates App Runner services with a placeholder image
# The services will be updated to use the actual ECR image using the update_app_runner.sh script

# App Runner service for the Discord bot
module "discord_bot_service" {
  count = local.deploy_app_runner ? 1 : 0
  source           = "./modules/apprunner-service"
  service_name     = "${var.app_name}-discord-bot-${var.environment}"
  # The image_identifier is not used since we're using a placeholder image in the module
  image_identifier = "${module.bot_repository.repository_url}:latest"
  port             = 8000
  environment_variables = {
    ENVIRONMENT = var.environment
    # Reference secrets using the format ${SECRETS_MANAGER_SECRET_NAME}:${JSON_KEY}
    DISCORD_BOT_TOKEN    = "${aws_secretsmanager_secret.discord_credentials.name}:DISCORD_BOT_TOKEN"
    DISCORD_CHANNEL_ID   = "${aws_secretsmanager_secret.discord_credentials.name}:DISCORD_CHANNEL_ID"
    DISCORD_SERVER_ID    = "${aws_secretsmanager_secret.discord_credentials.name}:DISCORD_SERVER_ID"
    TARGET_USER_ID       = "${aws_secretsmanager_secret.discord_credentials.name}:TARGET_USER_ID"
    DISCORD_WEBHOOK_URL  = "${aws_secretsmanager_secret.discord_credentials.name}:DISCORD_WEBHOOK_URL"
    OPENAI_API_KEY       = "${aws_secretsmanager_secret.openai_credentials.name}:OPENAI_API_KEY"
  }
  tags = local.tags
}

# App Runner service for the API
module "api_service" {
  count = local.deploy_app_runner ? 1 : 0
  source           = "./modules/apprunner-service"
  service_name     = "${var.app_name}-api-${var.environment}"
  # The image_identifier is not used since we're using a placeholder image in the module
  image_identifier = "${module.api_repository.repository_url}:latest"
  port             = 8000
  environment_variables = {
    ENVIRONMENT = var.environment
    OPENAI_API_KEY = "${aws_secretsmanager_secret.openai_credentials.name}:OPENAI_API_KEY"
  }
  tags = local.tags
}

# Outputs for App Runner services
output "discord_bot_service_url" {
  description = "URL of the App Runner Discord bot service"
  value       = local.deploy_app_runner ? module.discord_bot_service[0].service_url : "Not deployed"
}

output "discord_bot_service_arn" {
  description = "ARN of the App Runner Discord bot service"
  value       = local.deploy_app_runner ? module.discord_bot_service[0].service_arn : "Not deployed"
}

output "discord_bot_service_ecr_role_arn" {
  description = "ARN of the ECR access role for the Discord bot service"
  value       = local.deploy_app_runner ? module.discord_bot_service[0].ecr_access_role_arn : "Not deployed"
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
