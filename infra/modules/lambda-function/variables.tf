variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "handler" {
  description = "Handler for the Lambda function"
  type        = string
}

variable "runtime" {
  description = "Runtime for the Lambda function"
  type        = string
  default     = "python3.9"
}

variable "timeout" {
  description = "Timeout for the Lambda function in seconds"
  type        = number
  default     = 60
}

variable "memory_size" {
  description = "Memory size for the Lambda function in MB"
  type        = number
  default     = 128
}

variable "s3_bucket" {
  description = "S3 bucket containing the Lambda deployment package"
  type        = string
}

variable "s3_key" {
  description = "S3 key for the Lambda deployment package"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "schedule_expression" {
  description = "CloudWatch Events schedule expression to trigger the Lambda function (e.g., 'rate(1 hour)' or 'cron(0 12 * * ? *)')"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to the Lambda function and related resources"
  type        = map(string)
  default     = {}
}
