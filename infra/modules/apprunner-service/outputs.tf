output "service_url" {
  description = "URL of the App Runner service"
  value       = aws_apprunner_service.this.service_url
}

output "service_arn" {
  description = "ARN of the App Runner service"
  value       = aws_apprunner_service.this.arn
}

output "ecr_access_role_arn" {
  description = "ARN of the IAM role for ECR access"
  value       = aws_iam_role.apprunner_ecr_access.arn
}
