variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-west-3"
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
