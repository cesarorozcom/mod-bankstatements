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

variable "db_username" {
  description = "Master username for the PostgreSQL database"
  type        = string
  default     = "postgresadmin"
  sensitive   = true
}

variable "db_password" {
  description = "Master password for the PostgreSQL database"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "Instance class for the PostgreSQL database"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB for the PostgreSQL database"
  type        = number
  default     = 20
}
