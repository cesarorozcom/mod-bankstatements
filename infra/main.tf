resource "random_id" "bucket_suffix" {
  byte_length = 4
}

module "s3" {
  source = "./modules/s3"

  project_name  = var.project_name
  environment   = var.environment
  bucket_suffix = random_id.bucket_suffix.hex
  force_destroy = true
}

module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment
}


module "layers" {
  source = "./modules/layers"

  project_name = var.project_name
  environment  = var.environment
}

module "messaging" {
  source = "./modules/messaging"

  project_name = var.project_name
  environment  = var.environment
}

module "lambda" {
  source = "./modules/lambda"

  project_name                  = var.project_name
  environment                   = var.environment
  aws_region                    = var.aws_region
  lambda_role_arn               = module.iam.lambda_role_arn
  incoming_bucket               = module.s3.incoming_bucket_name
  rendered_bucket               = module.s3.rendered_bucket_name
  textract_bucket               = module.s3.textract_bucket_name
  data_bucket                   = module.s3.data_bucket_name
  pymupdf_layer_arn             = module.layers.pymupdf_layer_arn
  trp_layer_arn                 = module.layers.trp_layer_arn
  shared_layer_arn              = module.layers.shared_layer_arn
  textract_completion_topic_arn = module.messaging.textract_completion_topic_arn
  textract_publish_role_arn     = module.messaging.textract_publish_role_arn
}

module "stepfunctions" {
  source = "./modules/stepfunctions"

  project_name       = var.project_name
  environment        = var.environment
  incoming_bucket    = module.s3.incoming_bucket_name
  pdf_to_jpeg_arn    = module.lambda.pdf_to_jpeg_function_arn
  start_textract_arn = module.lambda.start_textract_job_function_arn
}
