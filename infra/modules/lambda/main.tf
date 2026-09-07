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

resource "aws_lambda_function" "pdf_to_jpeg" {
  function_name = "${var.project_name}-${var.environment}-pdf-to-jpeg"
  role          = var.lambda_role_arn
  handler       = "pdf_to_jpeg.app.handler"
  runtime       = "python3.12"
  timeout       = 300
  memory_size   = 1024

  filename         = data.archive_file.pdf_to_jpeg.output_path
  source_code_hash = data.archive_file.pdf_to_jpeg.output_base64sha256

  environment {
    variables = {
      INCOMING_BUCKET = var.incoming_bucket
      RENDERED_BUCKET = var.rendered_bucket
      AWS_REGION      = var.aws_region
    }
  }
}

resource "aws_lambda_permission" "allow_s3_pdf_to_jpeg" {
  statement_id  = "AllowS3InvokePdfToJpeg"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pdf_to_jpeg.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.incoming_bucket}"
}

resource "aws_s3_bucket_notification" "incoming_pdf_notification" {
  bucket = var.incoming_bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.pdf_to_jpeg.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "incoming/"
    filter_suffix       = ".pdf"
  }

  depends_on = [aws_lambda_permission.allow_s3_pdf_to_jpeg]
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

  environment {
    variables = {
      RENDERED_BUCKET = var.rendered_bucket
      TEXTRACT_BUCKET = var.textract_bucket
      DATA_BUCKET     = var.data_bucket
      AWS_REGION      = var.aws_region
    }
  }
}

resource "aws_lambda_permission" "allow_s3_start_textract_job" {
  statement_id  = "AllowS3InvokeStartTextractJob"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_textract_job.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.rendered_bucket}"
}

resource "aws_s3_bucket_notification" "rendered_image_notification" {
  bucket = var.rendered_bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.start_textract_job.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""
    filter_suffix       = ".jpg"
  }

  depends_on = [aws_lambda_permission.allow_s3_start_textract_job]
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

  environment {
    variables = {
      TEXTRACT_BUCKET = var.textract_bucket
      DATA_BUCKET     = var.data_bucket
      DB_HOST         = var.db_host
      DB_NAME         = var.db_name
      DB_USERNAME     = var.db_username
      DB_PASSWORD     = var.db_password
      AWS_REGION      = var.aws_region
    }
  }
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

  environment {
    variables = {
      DB_HOST     = var.db_host
      DB_NAME     = var.db_name
      DB_USERNAME = var.db_username
      DB_PASSWORD = var.db_password
      DATA_BUCKET  = var.data_bucket
      AWS_REGION  = var.aws_region
    }
  }
}
