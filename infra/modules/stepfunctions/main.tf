# ── Step Functions execution role ─────────────────────────────────────────────

data "aws_iam_policy_document" "stepfunctions_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "stepfunctions" {
  name               = "${var.project_name}-${var.environment}-stepfunctions-exec"
  assume_role_policy = data.aws_iam_policy_document.stepfunctions_assume_role.json
}

resource "aws_iam_role_policy" "stepfunctions_invoke_lambdas" {
  name = "${var.project_name}-${var.environment}-stepfunctions-invoke-lambdas"
  role = aws_iam_role.stepfunctions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["lambda:InvokeFunction"]
        Resource = [
          var.pdf_to_jpeg_arn,
          var.start_textract_arn,
        ]
      }
    ]
  })
}

# ── State machine (phase 1) ────────────────────────────────────────────────────
#
# Phase 1 renders the PDF and kicks off asynchronous Textract jobs, then ends.
# Textract publishes a completion message per job to an SNS topic; the
# process_textract_result Lambda (phase 2) reacts to that and invokes export_csv
# directly. This decoupling keeps the state machine to a handful of transitions
# regardless of how long Textract takes.
#
# Lambda invoked via "arn:aws:states:::lambda:invoke" wraps the function return
# value under a top-level "Payload" key in the result. All ResultSelector /
# next-state references must unwrap that key.

resource "aws_sfn_state_machine" "orchestration" {
  name     = "${var.project_name}-${var.environment}-document-orchestration"
  role_arn = aws_iam_role.stepfunctions.arn

  definition = jsonencode({
    Comment = "PDF to JPEG -> start async Textract jobs (completion handled out-of-band via SNS)"
    StartAt = "PdfToJpeg"
    States = {
      PdfToJpeg = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.pdf_to_jpeg_arn
          Payload = {
            "source_bucket.$" = "$.source_bucket"
            "source_key.$"    = "$.source_key"
          }
        }
        # Unwrap the Lambda Payload wrapper so downstream states see the
        # function's actual return value directly.
        ResultSelector = {
          "status.$"          = "$.Payload.status"
          "rendered_bucket.$" = "$.Payload.rendered_bucket"
          "rendered_keys.$"   = "$.Payload.rendered_keys"
        }
        ResultPath = "$.pdf_to_jpeg_result"
        Next       = "StartTextractJob"
      }

      StartTextractJob = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.start_textract_arn
          Payload = {
            "rendered_bucket.$" = "$.pdf_to_jpeg_result.rendered_bucket"
            "rendered_keys.$"   = "$.pdf_to_jpeg_result.rendered_keys"
          }
        }
        ResultSelector = {
          "status.$" = "$.Payload.status"
          "jobs.$"   = "$.Payload.jobs"
        }
        ResultPath = "$.start_textract_result"
        # Phase 1 ends here. Job completion is handled out-of-band: Textract
        # publishes to the SNS completion topic, which triggers
        # process_textract_result -> export_csv. No polling loop, no ExportCsv
        # task in this state machine.
        End = true
      }
    }
  })
}

# ── EventBridge rule: S3 PUT on incoming/*.pdf → start execution ───────────────

resource "aws_cloudwatch_event_rule" "incoming_pdf" {
  name        = "${var.project_name}-${var.environment}-incoming-pdf"
  description = "Trigger Step Functions when a PDF is uploaded to the incoming prefix"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = { name = [var.incoming_bucket] }
      object = { key = [{ suffix = ".pdf" }] }
    }
  })
}

resource "aws_iam_role" "eventbridge_sfn" {
  name = "${var.project_name}-${var.environment}-eventbridge-sfn"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "events.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge_start_execution" {
  name = "${var.project_name}-${var.environment}-eventbridge-start-execution"
  role = aws_iam_role.eventbridge_sfn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["states:StartExecution"]
      Resource = [aws_sfn_state_machine.orchestration.arn]
    }]
  })
}

resource "aws_cloudwatch_event_target" "sfn_target" {
  rule     = aws_cloudwatch_event_rule.incoming_pdf.name
  arn      = aws_sfn_state_machine.orchestration.arn
  role_arn = aws_iam_role.eventbridge_sfn.arn

  # Map the S3 event fields to the state machine input format.
  input_transformer {
    input_paths = {
      bucket = "$.detail.bucket.name"
      key    = "$.detail.object.key"
    }
    input_template = "{\"source_bucket\": \"<bucket>\", \"source_key\": \"<key>\"}"
  }
}
