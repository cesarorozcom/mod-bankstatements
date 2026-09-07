output "incoming_bucket_name" {
  description = "Incoming storage bucket for uploaded PDFs"
  value       = aws_s3_bucket.incoming.bucket
}

output "rendered_bucket_name" {
  description = "Rendered JPG bucket for stored image pages"
  value       = aws_s3_bucket.rendered.bucket
}

output "textract_bucket_name" {
  description = "Bucket for Textract result payloads"
  value       = aws_s3_bucket.textract.bucket
}

output "data_bucket_name" {
  description = "Bucket for exported CSV data"
  value       = aws_s3_bucket.data.bucket
}
