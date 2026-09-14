output "textract_completion_topic_arn" {
  description = "ARN of the SNS topic Textract publishes job completion to"
  value       = aws_sns_topic.textract_completion.arn
}

output "textract_publish_role_arn" {
  description = "ARN of the role Textract assumes to publish completion messages"
  value       = aws_iam_role.textract_publish.arn
}
