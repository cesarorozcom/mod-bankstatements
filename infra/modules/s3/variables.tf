variable "project_name" {
  description = "Project name prefix for S3 bucket names"
  type        = string
}

variable "environment" {
  description = "Environment name for S3 bucket names"
  type        = string
}

variable "bucket_suffix" {
  description = "Suffix appended to the bucket names to ensure uniqueness"
  type        = string
}

variable "force_destroy" {
  description = "Controls whether the bucket can be deleted forcefully in dev"
  type        = bool
  default     = true
}
