output "incoming_bucket_name" {
  description = "Name of the incoming S3 bucket"
  value       = module.s3.incoming_bucket_name
}

output "rendered_bucket_name" {
  description = "Name of the rendered JPEG S3 bucket"
  value       = module.s3.rendered_bucket_name
}

output "textract_bucket_name" {
  description = "Name of the Textract results S3 bucket"
  value       = module.s3.textract_bucket_name
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = module.iam.lambda_role_arn
}

output "step_functions_arn" {
  description = "ARN of the orchestration state machine"
  value       = module.stepfunctions.state_machine_arn
}
