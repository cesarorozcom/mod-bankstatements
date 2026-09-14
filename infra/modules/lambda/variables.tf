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

variable "pymupdf_layer_arn" {
  description = "ARN of the PyMuPDF Lambda layer"
  type        = string
}

variable "trp_layer_arn" {
  description = "ARN of the amazon-textract-response-parser Lambda layer"
  type        = string
}

variable "shared_layer_arn" {
  description = "ARN of the shared internal utilities Lambda layer"
  type        = string
}

variable "textract_completion_topic_arn" {
  description = "ARN of the SNS topic Textract publishes job completion to"
  type        = string
}

variable "textract_publish_role_arn" {
  description = "ARN of the role Textract assumes to publish completion messages"
  type        = string
}
