# AWS Provider configuration
provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "eli5-twitter-bot"
}

variable "environment" {
  description = "Deployment environment (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

# ECR Repository for Docker images
resource "aws_ecr_repository" "app_repo" {
  name                 = var.app_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = var.app_name
    Environment = var.environment
  }
}

# S3 bucket for model artifacts and data
resource "aws_s3_bucket" "model_bucket" {
  bucket = "${var.app_name}-models-${var.environment}"

  tags = {
    Name        = "${var.app_name}-models"
    Environment = var.environment
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "app_cluster" {
  name = "${var.app_name}-cluster-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "${var.app_name}-cluster"
    Environment = var.environment
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app_task" {
  family                   = "${var.app_name}-task-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = var.app_name
      image     = "${aws_ecr_repository.app_repo.repository_url}:latest"
      essential = true
      
      environment = [
        { name = "ENVIRONMENT", value = var.environment }
      ]
      
      secrets = [
        { name = "TWITTER_API_KEY", valueFrom = "${aws_secretsmanager_secret.twitter_credentials.arn}:TWITTER_API_KEY::" },
        { name = "TWITTER_API_SECRET", valueFrom = "${aws_secretsmanager_secret.twitter_credentials.arn}:TWITTER_API_SECRET::" },
        { name = "TWITTER_ACCESS_TOKEN", valueFrom = "${aws_secretsmanager_secret.twitter_credentials.arn}:TWITTER_ACCESS_TOKEN::" },
        { name = "TWITTER_ACCESS_TOKEN_SECRET", valueFrom = "${aws_secretsmanager_secret.twitter_credentials.arn}:TWITTER_ACCESS_TOKEN_SECRET::" },
        { name = "TWITTER_BEARER_TOKEN", valueFrom = "${aws_secretsmanager_secret.twitter_credentials.arn}:TWITTER_BEARER_TOKEN::" },
        { name = "TWITTER_ACCOUNT_HANDLE", valueFrom = "${aws_secretsmanager_secret.twitter_credentials.arn}:TWITTER_ACCOUNT_HANDLE::" },
        { name = "TWITTER_USER_ID", valueFrom = "${aws_secretsmanager_secret.twitter_credentials.arn}:TWITTER_USER_ID::" },
        { name = "OPENAI_API_KEY", valueFrom = "${aws_secretsmanager_secret.openai_credentials.arn}:OPENAI_API_KEY::" }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.app_name}-${var.environment}"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name        = "${var.app_name}-task"
    Environment = var.environment
  }
}

# IAM Roles
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.app_name}-execution-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-execution-role"
    Environment = var.environment
  }
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.app_name}-task-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-task-role"
    Environment = var.environment
  }
}

# Secrets Manager for credentials
resource "aws_secretsmanager_secret" "twitter_credentials" {
  name        = "${var.app_name}/twitter-credentials-${var.environment}"
  description = "Twitter API credentials for the ELI5 bot"

  tags = {
    Name        = "${var.app_name}-twitter-credentials"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret" "openai_credentials" {
  name        = "${var.app_name}/openai-credentials-${var.environment}"
  description = "OpenAI API credentials for the ELI5 bot"

  tags = {
    Name        = "${var.app_name}-openai-credentials"
    Environment = var.environment
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ecs/${var.app_name}-${var.environment}"
  retention_in_days = 30

  tags = {
    Name        = "${var.app_name}-logs"
    Environment = var.environment
  }
}

# Outputs
output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.app_repo.repository_url
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for model artifacts"
  value       = aws_s3_bucket.model_bucket.bucket
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.app_cluster.name
}
