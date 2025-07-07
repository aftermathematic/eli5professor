# Deployment type configuration
# This file defines variables and locals for controlling the deployment type

# Variable for deployment type
variable "deployment_type" {
  description = "Type of deployment to use (app_runner or lambda)"
  type        = string
  default     = "app_runner"
  
  validation {
    condition     = contains(["app_runner", "lambda"], var.deployment_type)
    error_message = "The deployment_type must be either 'app_runner' or 'lambda'."
  }
}

# Locals for conditional deployment
locals {
  deploy_app_runner = var.deployment_type == "app_runner"
  deploy_lambda     = var.deployment_type == "lambda"
}
