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
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          var.pdf_to_jpeg_arn,
          var.start_textract_arn,
          var.export_csv_arn,
        ]
      }
    ]
  })
}

resource "aws_sfn_state_machine" "orchestration" {
  name     = "${var.project_name}-${var.environment}-document-orchestration"
  role_arn = aws_iam_role.stepfunctions.arn
  definition = jsonencode({
    Comment = "PDF to JPEG -> Textract -> Export workflow"
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
        ResultPath = "$.pdf_to_jpeg_result"
        Next       = "StartTextractJob"
      }
      StartTextractJob = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.start_textract_arn
          Payload = {
            "rendered_keys.$" = "$.pdf_to_jpeg_result.rendered_keys"
            "source_bucket.$" = "$.pdf_to_jpeg_result.source_bucket"
            "source_key.$"    = "$.pdf_to_jpeg_result.source_key"
          }
        }
        ResultPath = "$.start_textract_result"
        Next       = "ExportCsv"
      }
      ExportCsv = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.export_csv_arn
          Payload = {
            "jobs.$" = "$.start_textract_result.jobs"
            "source_bucket.$" = "$.pdf_to_jpeg_result.source_bucket"
            "source_key.$" = "$.pdf_to_jpeg_result.source_key"
          }
        }
        ResultPath = "$.export_csv_result"
        End        = true
      }
    }
  })
}
