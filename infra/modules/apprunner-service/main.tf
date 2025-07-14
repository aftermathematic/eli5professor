resource "aws_apprunner_service" "this" {
  service_name = var.service_name

  source_configuration {
    # Use the actual ECR image
    image_repository {
      image_configuration {
        port = var.port
        runtime_environment_variables = var.environment_variables
      }
      image_identifier      = var.image_identifier
      image_repository_type = "ECR"
    }

    # Enable auto deployments for ECR images
    auto_deployments_enabled = true
    
    # Add authentication configuration for ECR access
    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_ecr_access.arn
    }
  }

  # Add instance configuration for better performance
  instance_configuration {
    cpu               = "1 vCPU"
    memory            = "2 GB"
    instance_role_arn = aws_iam_role.apprunner_instance.arn
  }

  tags = var.tags
}

resource "aws_iam_role" "apprunner_ecr_access" {
  name = "${var.service_name}-ecr-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "apprunner_ecr_access" {
  role       = aws_iam_role.apprunner_ecr_access.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# Instance role for App Runner service to access AWS services
resource "aws_iam_role" "apprunner_instance" {
  name = "${var.service_name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "tasks.apprunner.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Policy for accessing Secrets Manager
resource "aws_iam_role_policy" "apprunner_secrets_access" {
  name = "${var.service_name}-secrets-access"
  role = aws_iam_role.apprunner_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:*:*:secret:eli5-*",
          "arn:aws:secretsmanager:*:*:secret:openai-*"
        ]
      }
    ]
  })
}

# ECR access role ARN is exposed via outputs.tf
