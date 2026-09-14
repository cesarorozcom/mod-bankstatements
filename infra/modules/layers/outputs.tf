output "shared_layer_arn" {
  description = "ARN of the shared utilities Lambda layer"
  value       = aws_lambda_layer_version.shared.arn
}

output "pymupdf_layer_arn" {
  description = "ARN of the PyMuPDF Lambda layer"
  value       = aws_lambda_layer_version.pymupdf.arn
}

output "trp_layer_arn" {
  description = "ARN of the amazon-textract-response-parser Lambda layer"
  value       = aws_lambda_layer_version.trp.arn
}
