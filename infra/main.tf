resource "random_id" "bucket_suffix" {
  byte_length = 4
}

module "s3" {
  source = "./modules/s3"

  project_name    = var.project_name
  environment     = var.environment
  bucket_suffix   = random_id.bucket_suffix.hex
  force_destroy   = true
}

module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment
}

module "database" {
  source = "./modules/database"

  project_name        = var.project_name
  environment         = var.environment
  db_name             = "text_extract_demo"
  db_username         = var.db_username
  db_password         = var.db_password
  db_instance_class   = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
}

module "lambda" {
  source = "./modules/lambda"

  project_name         = var.project_name
  environment          = var.environment
  aws_region           = var.aws_region
  lambda_role_arn      = module.iam.lambda_role_arn
  incoming_bucket      = module.s3.incoming_bucket_name
  rendered_bucket      = module.s3.rendered_bucket_name
  textract_bucket      = module.s3.textract_bucket_name
  data_bucket          = module.s3.data_bucket_name
  db_host              = module.database.db_host
  db_name              = module.database.db_name
  db_username          = var.db_username
  db_password          = var.db_password
}

module "stepfunctions" {
  source = "./modules/stepfunctions"

  project_name       = var.project_name
  environment        = var.environment
  pdf_to_jpeg_arn    = module.lambda.pdf_to_jpeg_function_arn
  start_textract_arn = module.lambda.start_textract_job_function_arn
  export_csv_arn     = module.lambda.export_csv_function_arn
}
