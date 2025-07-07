# AWS Provider configuration
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"  # Using an older version that might be more stable
    }
  }
}

provider "aws" {
  region = var.aws_region
  # Skip validation for testing purposes
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

# Locals
locals {
  tags = {
    Name        = var.app_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# S3 bucket for model artifacts and data
module "model_bucket" {
  source      = "./modules/s3-bucket"
  bucket_name = "${var.app_name}-models-${var.environment}"
  tags        = local.tags
}

# ECR Repository for Docker images
module "app_repository" {
  source          = "./modules/ecr-repository"
  repository_name = "${var.app_name}-${var.environment}"
  tags            = local.tags
}

# Secrets Manager for credentials
resource "aws_secretsmanager_secret" "twitter_credentials" {
  name        = "${var.app_name}/twitter-credentials-${var.environment}"
  description = "Twitter API credentials for the ELI5 bot"

  tags = local.tags
}

resource "aws_secretsmanager_secret" "openai_credentials" {
  name        = "${var.app_name}/openai-credentials-${var.environment}"
  description = "OpenAI API credentials for the ELI5 bot"

  tags = local.tags
}

# App Runner services are defined in app_runner.tf
# They should be used after the Docker image has been pushed to ECR
