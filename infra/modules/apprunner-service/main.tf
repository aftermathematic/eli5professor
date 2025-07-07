resource "aws_apprunner_service" "this" {
  service_name = var.service_name

  source_configuration {
    # Use a public ECR image as a placeholder
    # This will be updated to the actual ECR image after it's pushed
    image_repository {
      image_configuration {
        port = var.port
        runtime_environment_variables = var.environment_variables
      }
      image_identifier      = "public.ecr.aws/nginx/nginx:latest"
      image_repository_type = "ECR_PUBLIC"
    }

    # Auto deployments are not supported for public ECR images
    auto_deployments_enabled = false
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

# ECR access role ARN is exposed via outputs.tf
