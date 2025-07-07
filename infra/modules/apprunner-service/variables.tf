variable "service_name" {
  description = "Name of the App Runner service"
  type        = string
}

variable "image_identifier" {
  description = "ECR image identifier (URL and tag)"
  type        = string
}

variable "port" {
  description = "Port the application listens on"
  type        = number
  default     = 8000
}

variable "environment_variables" {
  description = "Environment variables for the App Runner service"
  type        = map(string)
  default     = {}
}

variable "auto_deployments_enabled" {
  description = "Whether to automatically deploy new images (Note: Not used for public ECR images as they don't support auto deployments)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to the App Runner service"
  type        = map(string)
  default     = {}
}
