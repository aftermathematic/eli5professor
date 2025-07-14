# ECR Repository for API Docker images
module "api_repository" {
  source          = "./modules/ecr-repository"
  repository_name = "${var.app_name}-api-${var.environment}"
  tags            = local.tags
}

# ECR Repository for Bot Docker images
module "bot_repository" {
  source          = "./modules/ecr-repository"
  repository_name = "${var.app_name}-bot-${var.environment}"
  tags            = local.tags
}

# Update outputs
output "api_repository_url" {
  description = "URL of the API ECR repository"
  value       = module.api_repository.repository_url
}

output "bot_repository_url" {
  description = "URL of the Bot ECR repository"
  value       = module.bot_repository.repository_url
}
