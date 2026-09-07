# Text Extract Demo

This project turns the prototype bank-statement extraction flow into a Terraform-managed AWS serverless pipeline.

## Documentation status

This README is aligned with:

- [ADR 0001: Serverless Textract Orchestration and CSV Data Sink](docs/adr/0001-serverless-textract-orchestration.md)
- Current implementation under `infra/` and `lambda/src/`

## Architecture overview

The production flow is:

1. Upload a PDF to the incoming S3 bucket.
2. A Lambda function renders each PDF page to JPEG and stores it in the rendered bucket.
3. A second Lambda starts an AWS Textract analysis job for the rendered page images.
4. The export Lambda polls Textract by `job_id` (`get_document_analysis`), converts movement rows to CSV, and writes the file to the data bucket in S3.

This flow is orchestrated by AWS Step Functions with state order:

`pdf_to_jpeg -> start_textract_job -> export_csv`

Each state consumes predecessor output (for example `start_textract_job` reads `rendered_keys` produced by `pdf_to_jpeg`).

Typical payload handoff shape:

```json
{
   "status": str,
   "source_bucket": str,
   "source_key": str,
   "rendered_keys": List
}
```

`start_textract_job` emits `jobs[*].job_id`; `export_csv` polls `get_document_analysis` until completion and writes CSV artifacts to the data bucket.

This aligns with the current extraction logic in:

- [lambda/src/pdf_to_jpeg/app.py](lambda/src/pdf_to_jpeg/app.py)
- [lambda/src/start_textract_job/app.py](lambda/src/start_textract_job/app.py)
- [lambda/src/export_csv/app.py](lambda/src/export_csv/app.py)
- [lambda/src/shared/s3_utils.py](lambda/src/shared/s3_utils.py)
- [lambda/src/shared/textract_utils.py](lambda/src/shared/textract_utils.py)

## Core data model

- `movement_id`
- `operation_date`
- `value_date`
- `description`
- `credits`
- `debit`
- `balance`

The database module adds document metadata and status tracking around the movement rows so the pipeline can manage uploads and processing state.

## Directory structure

- `infra/` — Terraform deployment for AWS resources
- `infra/modules/` — reusable Terraform modules for S3, IAM, Lambda, database, and Step Functions
- `lambda/src/pdf_to_jpeg/` — PDF page rendering to JPEG
- `lambda/src/start_textract_job/` — starts Textract async analysis per rendered image
- `lambda/src/export_csv/` — polls Textract jobs and writes CSV to data bucket
- `lambda/src/shared/` — shared S3/Textract utilities for Lambda reuse
- `lambda/src/process_textract_result/` — non-orchestrated parser module kept for optional/legacy use
- `docs/adr/` — architecture decision records
- `docs/` — sample Textract outputs and local JSON fixtures

## Prerequisites

Before you run the deployment, install:

- Terraform v1.5+
- AWS CLI configured with credentials for your target account
- Python 3.11+
- `pip` and `virtualenv` if you want to validate the Lambda code locally

## Terraform deployment

1. Change into the `infra` directory:

   ```bash
   cd infra
   ```

2. Copy the example variables file:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Edit `terraform.tfvars` with your values:

   - `aws_region`
   - `project_name`
   - `environment`
   - `db_username`
   - `db_password`

4. Initialize Terraform:

   ```bash
   terraform init
   ```

5. Validate the configuration:

   ```bash
   terraform validate
   ```

6. Create the deployment plan:

   ```bash
   terraform plan
   ```

7. Apply the stack:

   ```bash
   terraform apply
   ```

### Optional local checks

```bash
source .venv/bin/activate
python -m compileall lambda/src
```

If `terraform` is not installed in your environment, install it first before running `init/validate/plan`.

## Lambda build notes

The Terraform configuration packages the source files under `lambda/src/` into ZIP archives automatically when `terraform apply` runs. The included skeleton functions are intentionally simple and ready to be extended with production-grade validation, retries, and database inserts.

Shared reusable utilities live under `lambda/src/shared/` (for example `s3_utils.py` and `textract_utils.py`) and are included in Lambda packaging for cross-function reuse.

Current orchestration target is the 3-step workflow in ADR 0001. `process_textract_result` remains available but is not in the active state machine path.

## AWS permissions

The IAM module creates the execution role used by the Lambda functions. It grants the needed least-privilege access for:

- S3 object read/write access to the relevant buckets
- Textract analysis job access
- CloudWatch Logs access
- Database connectivity via environment variables

## Security recommendations

- Store database credentials in AWS Secrets Manager or environment secrets instead of hardcoded values.
- Keep the bucket policy restricted to the Lambda execution role and the required admin identities.
- Use a dedicated VPC or subnet setup for the database if your environment requires tighter network isolation.

## Next steps

1. Add robust pagination handling checks for all Textract polling paths.
2. Move DB credentials to AWS Secrets Manager.
3. Add dead-letter queues and retry policies for failed stages.
4. Add ADR 0002 for idempotency and duplicate-processing prevention.

## Architecture Decision Records

- [docs/adr/0001-serverless-textract-orchestration.md](docs/adr/0001-serverless-textract-orchestration.md)
