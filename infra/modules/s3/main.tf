resource "aws_s3_bucket" "incoming" {
  bucket        = "${var.project_name}-${var.environment}-incoming-${var.bucket_suffix}"
  force_destroy = var.force_destroy
}

# Enable EventBridge notifications so S3 object events are forwarded to
# EventBridge, allowing the Step Functions rule to trigger on PDF uploads.
resource "aws_s3_bucket_notification" "incoming_eventbridge" {
  bucket      = aws_s3_bucket.incoming.id
  eventbridge = true
}

resource "aws_s3_bucket" "rendered" {
  bucket        = "${var.project_name}-${var.environment}-rendered-${var.bucket_suffix}"
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket" "textract" {
  bucket        = "${var.project_name}-${var.environment}-textract-${var.bucket_suffix}"
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket" "data" {
  bucket        = "${var.project_name}-${var.environment}-data-${var.bucket_suffix}"
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_public_access_block" "incoming" {
  bucket                  = aws_s3_bucket.incoming.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "rendered" {
  bucket                  = aws_s3_bucket.rendered.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "textract" {
  bucket                  = aws_s3_bucket.textract.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
