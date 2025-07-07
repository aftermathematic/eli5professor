output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.this.invoke_arn
}

output "role_name" {
  description = "Name of the IAM role for the Lambda function"
  value       = aws_iam_role.lambda_exec.name
}

output "role_arn" {
  description = "ARN of the IAM role for the Lambda function"
  value       = aws_iam_role.lambda_exec.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch Log Group for the Lambda function"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "schedule_rule_arn" {
  description = "ARN of the CloudWatch Events rule for the Lambda function schedule"
  value       = length(aws_cloudwatch_event_rule.schedule) > 0 ? aws_cloudwatch_event_rule.schedule[0].arn : null
}
