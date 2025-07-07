output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.app_repository.repository_url
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for model artifacts"
  value       = module.model_bucket.bucket_id
}

output "s3_bucket_id" {
  description = "ID of the S3 bucket for model artifacts"
  value       = module.model_bucket.bucket_id
}

# App Runner service outputs are defined in app_runner.tf
# They should be used after the Docker image has been pushed to ECR

# Lambda function outputs are defined in lambda.tf
# They should be used after the Lambda functions have been deployed
