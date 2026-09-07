variable "project_name" {
  description = "Project name prefix for the Step Functions state machine"
  type        = string
}

variable "environment" {
  description = "Environment name used in state machine naming"
  type        = string
}

variable "pdf_to_jpeg_arn" {
  description = "ARN of the PDF-to-JPEG Lambda"
  type        = string
}

variable "start_textract_arn" {
  description = "ARN of the Textract start Lambda"
  type        = string
}

variable "export_csv_arn" {
  description = "ARN of the CSV export Lambda"
  type        = string
}
