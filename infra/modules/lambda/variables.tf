variable "project_name" {
  description = "Project name used to compose Lambda names"
  type        = string
}

variable "environment" {
  description = "Environment identifier used in Lambda names"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "lambda_role_arn" {
  description = "ARN of the execution role used by the Lambda functions"
  type        = string
}

variable "incoming_bucket" {
  description = "Incoming PDF bucket"
  type        = string
}

variable "rendered_bucket" {
  description = "Rendered JPEG bucket"
  type        = string
}

variable "textract_bucket" {
  description = "S3 bucket for Textract result payloads"
  type        = string
}

variable "data_bucket" {
  description = "S3 bucket for exported CSV data"
  type        = string
}

variable "db_host" {
  description = "Database hostname"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}
