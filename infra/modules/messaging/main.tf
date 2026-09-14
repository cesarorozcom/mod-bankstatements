# ── SNS topic for Textract job completion notifications ────────────────────────
#
# Amazon Textract publishes one completion message per asynchronous job to this
# topic. The process_textract_result Lambda subscribes to it and drives phase 2
# of the workflow (fetch results -> invoke export_csv). This replaces the
# Step Functions polling loop, eliminating per-poll state transitions.

resource "aws_sns_topic" "textract_completion" {
  name = "${var.project_name}-${var.environment}-textract-completion"
}

# ── Role that Textract assumes to publish completion messages to the topic ─────

data "aws_iam_policy_document" "textract_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["textract.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "textract_publish" {
  name               = "${var.project_name}-${var.environment}-textract-publish"
  assume_role_policy = data.aws_iam_policy_document.textract_assume_role.json
}

resource "aws_iam_role_policy" "textract_publish" {
  name = "${var.project_name}-${var.environment}-textract-publish"
  role = aws_iam_role.textract_publish.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [aws_sns_topic.textract_completion.arn]
      }
    ]
  })
}
