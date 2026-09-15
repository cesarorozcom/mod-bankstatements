# Bank Statement Extraction Pipeline

A Terraform-managed AWS serverless pipeline that converts PDF bank statements into structured CSV movement records using Amazon Textract.

## Documentation status

This README reflects the current implementation under `infra/` and `lambda/src/`, and is aligned with:

- [ADR 0001: Serverless Textract Orchestration and CSV Data Sink](docs/adr/0001-serverless-textract-orchestration.md) — original architecture.
- [ADR 0003: Decoupled Two-Phase Textract Completion via SNS](docs/adr/0003-decoupled-textract-completion-via-sns.md) — the current completion design, which supersedes the earlier polling approach.

## Architecture overview

The pipeline runs in two phases so that it never blocks or polls while Amazon Textract processes documents asynchronously.

Phase 1 is orchestrated by AWS Step Functions and ends as soon as the Textract jobs are started:

1. A PDF is uploaded to the incoming S3 bucket. An EventBridge rule starts the state machine.
2. The `pdf_to_jpeg` Lambda renders each PDF page to a JPEG and stores it in the rendered bucket.
3. The `start_textract_job` Lambda starts one asynchronous Textract analysis job per rendered page, attaching an SNS notification channel, then the state machine ends.

Phase 2 is event-driven and uses no Step Functions transitions:

4. Textract publishes a completion message per job to the SNS completion topic.
5. The `process_textract_result` Lambda, subscribed to that topic, reacts to each completed job and invokes `export_csv` asynchronously.
6. The `export_csv` Lambda fetches the analysis result, parses movement rows, and writes a CSV to the data bucket under the `exports/` prefix (one CSV per page, named by job id).

This decoupling keeps the state machine to a small, constant number of transitions regardless of how long or how many Textract jobs run, which keeps the workflow within a tight free-tier transition budget. See ADR 0003 for the rationale and tradeoffs.

## Core data model

Each parsed movement row maps to the following fields:

- `movement_id`
- `operation_date`
- `value_date`
- `description`
- `credits`
- `debit`
- `balance`

## Deployment status

- The infrastructure is deployed and managed through Terraform in the `infra/` directory.
- The four buckets (incoming, rendered, textract, data) and the SNS completion topic are provisioned by Terraform.
- The Step Functions state machine, the four Lambda functions, and the SNS-driven completion path are live.
- Terraform state and variable files (`terraform.tfstate*`, `terraform.tfvars`) are environment specific and are not intended to be shared; keep them out of version control.

## Directory structure

- `infra/` — Terraform deployment for AWS resources.
- `infra/modules/s3/` — incoming, rendered, textract, and data buckets.
- `infra/modules/iam/` — shared Lambda execution role and least-privilege policies.
- `infra/modules/lambda/` — the four Lambda functions plus the SNS subscription and invoke wiring.
- `infra/modules/layers/` — Lambda layers (PyMuPDF, Textract response parser, shared utilities).
- `infra/modules/messaging/` — SNS completion topic and the role Textract assumes to publish to it.
- `infra/modules/stepfunctions/` — the Phase 1 state machine and the EventBridge trigger.
- `lambda/src/pdf_to_jpeg/` — renders PDF pages to JPEG.
- `lambda/src/start_textract_job/` — starts asynchronous Textract jobs with an SNS notification channel.
- `lambda/src/process_textract_result/` — reacts to Textract completion and invokes the exporter.
- `lambda/src/export_csv/` — parses Textract results and writes CSV to the data bucket.
- `lambda/src/shared/` — shared S3 and Textract helper utilities.
- `docs/adr/` — architecture decision records.

## Prerequisites

- Terraform v1.5 or later.
- AWS CLI configured with credentials for the target account.
- Python 3.12 (the Lambda runtime) for local validation of function source.

## Configuration

Deployment is configured through three Terraform variables, all with defaults in `infra/variables.tf`:

- `aws_region` — target region (default `us-east-1`).
- `project_name` — name prefix applied to all resources.
- `environment` — environment suffix, such as `dev`.

Override any of these in a `terraform.tfvars` file or on the command line. No database or credential variables are required; the pipeline has no database component.

## Deployment

Run the standard Terraform lifecycle from the `infra/` directory:

- Initialize providers and modules: `terraform init`
- Validate the configuration: `terraform validate`
- Preview changes: `terraform plan`
- Apply the stack: `terraform apply`

Terraform packages the Lambda source under `lambda/src/` into deployment archives automatically during `apply`, so no separate build step is required.

## AWS permissions

The IAM module creates the execution role shared by the Lambda functions, granting least-privilege access for:

- S3 read and write access scoped to the project buckets.
- Textract analysis operations.
- Passing the Textract publish role (scoped to the Textract service) so completion notifications can be sent.
- Invoking the `export_csv` function from the completion handler.
- CloudWatch Logs access.

The `messaging` module creates a separate role that Amazon Textract assumes solely to publish completion messages to the SNS topic.

## Security recommendations

- Keep Terraform state and `terraform.tfvars` out of version control; they can contain account identifiers and other environment detail.
- Restrict bucket access to the Lambda execution role and required admin identities.
- Store any secrets in AWS Secrets Manager rather than in variables or environment values.

## Known gaps and next steps

- No dead-letter queue or retry policy yet on the SNS to `process_textract_result` to `export_csv` path.
- Output is one CSV per page; consolidating to a single CSV per source document would require an aggregation step.
- Textract result pagination should be verified across all parsing paths.
- Single-execution traceability is reduced by the decoupled design; correlation across stages relies on the Textract job id in CloudWatch logs.

## Architecture Decision Records

- [docs/adr/0001-serverless-textract-orchestration.md](docs/adr/0001-serverless-textract-orchestration.md)
- [docs/adr/0003-decoupled-textract-completion-via-sns.md](docs/adr/0003-decoupled-textract-completion-via-sns.md)
