locals {
  layers_src_dir = "${path.module}/../../../lambda/layers"
}

# ── shared utilities layer (used by all functions) ────────────────────────────

data "archive_file" "shared_layer" {
  type        = "zip"
  source_dir  = "${local.layers_src_dir}/shared"
  output_path = "${path.module}/../../../lambda/build/layer_shared.zip"
}

resource "aws_lambda_layer_version" "shared" {
  layer_name          = "${var.project_name}-${var.environment}-shared"
  filename            = data.archive_file.shared_layer.output_path
  source_code_hash    = data.archive_file.shared_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]
  description         = "Shared internal utilities (s3_utils, textract_utils)"
}

# ── PyMuPDF layer (used by pdf_to_jpeg) ──────────────────────────────────────

resource "null_resource" "build_pymupdf" {
  triggers = {
    requirements = filemd5("${local.layers_src_dir}/pymupdf/requirements.txt")
  }

  provisioner "local-exec" {
    command = <<-EOT
      pip install \
        --platform manylinux2014_x86_64 \
        --target "${local.layers_src_dir}/pymupdf/python" \
        --implementation cp \
        --python-version 3.12 \
        --only-binary=:all: \
        --upgrade \
        -r "${local.layers_src_dir}/pymupdf/requirements.txt"
    EOT
  }
}

data "archive_file" "pymupdf_layer" {
  type        = "zip"
  source_dir  = "${local.layers_src_dir}/pymupdf"
  output_path = "${path.module}/../../../lambda/build/layer_pymupdf.zip"

  depends_on = [null_resource.build_pymupdf]
}

resource "aws_lambda_layer_version" "pymupdf" {
  layer_name          = "${var.project_name}-${var.environment}-pymupdf"
  filename            = data.archive_file.pymupdf_layer.output_path
  source_code_hash    = data.archive_file.pymupdf_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]
  description         = "PyMuPDF (fitz) for PDF rendering"
}

# ── amazon-textract-response-parser layer (used by export_csv) ───────────────

resource "null_resource" "build_trp" {
  triggers = {
    requirements = filemd5("${local.layers_src_dir}/trp/requirements.txt")
  }

  provisioner "local-exec" {
    command = <<-EOT
      pip install \
        --platform manylinux2014_x86_64 \
        --target "${local.layers_src_dir}/trp/python" \
        --implementation cp \
        --python-version 3.12 \
        --only-binary=:all: \
        --upgrade \
        -r "${local.layers_src_dir}/trp/requirements.txt"
    EOT
  }
}

data "archive_file" "trp_layer" {
  type        = "zip"
  source_dir  = "${local.layers_src_dir}/trp"
  output_path = "${path.module}/../../../lambda/build/layer_trp.zip"

  depends_on = [null_resource.build_trp]
}

resource "aws_lambda_layer_version" "trp" {
  layer_name          = "${var.project_name}-${var.environment}-trp"
  filename            = data.archive_file.trp_layer.output_path
  source_code_hash    = data.archive_file.trp_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]
  description         = "amazon-textract-response-parser for Textract result parsing"
}
