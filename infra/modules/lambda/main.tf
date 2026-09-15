data "archive_file" "pdf_to_jpeg" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/src"
  output_path = "${path.module}/../../../lambda/build/pdf_to_jpeg.zip"
  excludes    = ["pdf_to_jpeg/__pycache__", "start_textract_job/__pycache__", "process_textract_result/__pycache__", "export_csv/__pycache__", "shared/__pycache__"]
}

data "archive_file" "start_textract_job" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/src"
  output_path = "${path.module}/../../../lambda/build/start_textract_job.zip"
  excludes    = ["pdf_to_jpeg/__pycache__", "start_textract_job/__pycache__", "process_textract_result/__pycache__", "export_csv/__pycache__", "shared/__pycache__"]
}

data "archive_file" "process_textract_result" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/src"
  output_path = "${path.module}/../../../lambda/build/process_textract_result.zip"
  excludes    = ["pdf_to_jpeg/__pycache__", "start_textract_job/__pycache__", "process_textract_result/__pycache__", "export_csv/__pycache__", "shared/__pycache__"]
}

data "archive_file" "export_csv" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/src"
  output_path = "${path.module}/../../../lambda/build/export_csv.zip"
  excludes    = ["pdf_to_jpeg/__pycache__", "start_textract_job/__pycache__", "process_textract_result/__pycache__", "export_csv/__pycache__", "shared/__pycache__"]
}

resource "aws_cloudwatch_log_group" "pdf_to_jpeg" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-pdf-to-jpeg"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "start_textract_job" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-start-textract-job"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "process_textract_result" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-process-textract-result"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "export_csv" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-export-csv"
  retention_in_days = 14
}

resource "aws_lambda_function" "pdf_to_jpeg" {
  function_name = "${var.project_name}-${var.environment}-pdf-to-jpeg"
  role          = var.lambda_role_arn
  handler       = "pdf_to_jpeg.app.handler"
  runtime       = "python3.12"
  timeout       = 300
  memory_size   = 1024

  filename         = data.archive_file.pdf_to_jpeg.output_path
  source_code_hash = data.archive_file.pdf_to_jpeg.output_base64sha256

  layers = [var.pymupdf_layer_arn, var.shared_layer_arn]

  depends_on = [aws_cloudwatch_log_group.pdf_to_jpeg]

  environment {
    variables = {
      INCOMING_BUCKET = var.incoming_bucket
      RENDERED_BUCKET = var.rendered_bucket
    }
  }
}

resource "aws_lambda_permission" "allow_s3_pdf_to_jpeg" {
  statement_id  = "AllowStepFunctionsInvokePdfToJpeg"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pdf_to_jpeg.function_name
  principal     = "states.amazonaws.com"
}

resource "aws_lambda_function" "start_textract_job" {
  function_name = "${var.project_name}-${var.environment}-start-textract-job"
  role          = var.lambda_role_arn
  handler       = "start_textract_job.app.handler"
  runtime       = "python3.12"
  timeout       = 300
  memory_size   = 1024

  filename         = data.archive_file.start_textract_job.output_path
  source_code_hash = data.archive_file.start_textract_job.output_base64sha256

  layers = [var.shared_layer_arn]

  depends_on = [aws_cloudwatch_log_group.start_textract_job]

  environment {
    variables = {
      RENDERED_BUCKET           = var.rendered_bucket
      TEXTRACT_BUCKET           = var.textract_bucket
      DATA_BUCKET               = var.data_bucket
      TEXTRACT_SNS_TOPIC_ARN    = var.textract_completion_topic_arn
      TEXTRACT_PUBLISH_ROLE_ARN = var.textract_publish_role_arn
    }
  }
}

resource "aws_lambda_permission" "allow_stepfunctions_start_textract_job" {
  statement_id  = "AllowStepFunctionsInvokeStartTextractJob"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_textract_job.function_name
  principal     = "states.amazonaws.com"
}

resource "aws_lambda_function" "process_textract_result" {
  function_name = "${var.project_name}-${var.environment}-process-textract-result"
  role          = var.lambda_role_arn
  handler       = "process_textract_result.app.handler"
  runtime       = "python3.12"
  timeout       = 300
  memory_size   = 1024

  filename         = data.archive_file.process_textract_result.output_path
  source_code_hash = data.archive_file.process_textract_result.output_base64sha256

  layers = [var.shared_layer_arn]

  depends_on = [aws_cloudwatch_log_group.process_textract_result]

  environment {
    variables = {
      TEXTRACT_BUCKET     = var.textract_bucket
      DATA_BUCKET         = var.data_bucket
      EXPORT_CSV_FUNCTION = aws_lambda_function.export_csv.function_name
    }
  }
}

# Phase 2 trigger: Textract completion SNS -> process_textract_result.
resource "aws_sns_topic_subscription" "textract_completion_to_processor" {
  topic_arn = var.textract_completion_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.process_textract_result.arn
}

resource "aws_lambda_permission" "allow_sns_invoke_processor" {
  statement_id  = "AllowSNSInvokeProcessTextractResult"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_textract_result.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.textract_completion_topic_arn
}

resource "aws_lambda_function" "export_csv" {
  function_name = "${var.project_name}-${var.environment}-export-csv"
  role          = var.lambda_role_arn
  handler       = "export_csv.app.handler"
  runtime       = "python3.12"
  timeout       = 300
  memory_size   = 1024

  filename         = data.archive_file.export_csv.output_path
  source_code_hash = data.archive_file.export_csv.output_base64sha256

  layers = [var.trp_layer_arn, var.shared_layer_arn]

  depends_on = [aws_cloudwatch_log_group.export_csv]

  environment {
    variables = {
      DATA_BUCKET = var.data_bucket
    }
  }
}
