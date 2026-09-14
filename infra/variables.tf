variable "aws_region" {
  description = "AWS region for the deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Base project name used across resources"
  type        = string
  default     = "text-extract-demo"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}
