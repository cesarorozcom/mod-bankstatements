output "pdf_to_jpeg_function_name" {
  description = "PDF-to-JPEG Lambda function name"
  value       = aws_lambda_function.pdf_to_jpeg.function_name
}

output "pdf_to_jpeg_function_arn" {
  description = "PDF-to-JPEG Lambda function ARN"
  value       = aws_lambda_function.pdf_to_jpeg.arn
}

output "start_textract_job_function_name" {
  description = "Textract starter Lambda function name"
  value       = aws_lambda_function.start_textract_job.function_name
}

output "start_textract_job_function_arn" {
  description = "Textract starter Lambda function ARN"
  value       = aws_lambda_function.start_textract_job.arn
}

output "process_textract_result_function_name" {
  description = "Textract parser Lambda function name"
  value       = aws_lambda_function.process_textract_result.function_name
}

output "process_textract_result_function_arn" {
  description = "Textract parser Lambda function ARN"
  value       = aws_lambda_function.process_textract_result.arn
}

output "export_csv_function_name" {
  description = "CSV export Lambda function name"
  value       = aws_lambda_function.export_csv.function_name
}

output "export_csv_function_arn" {
  description = "CSV export Lambda function ARN"
  value       = aws_lambda_function.export_csv.arn
}
