# ADR 0001: Serverless Textract Orchestration and CSV Data Sink

- Status: Accepted
- Date: 2026-09-07
- Deciders: Project maintainers
- Technical story: Convert PDF bank statements into structured movement records and persist export artifacts as CSV in S3.

## Context

This codebase started as local scripts that:

1. Convert PDF pages to JPEG images.
2. Call AWS Textract to detect table and form data.
3. Parse movement rows into a normalized schema based on the MovementItem fields:
- movement_id
- operation_date
- value_date
- description
- credits
- debit
- balance

The project now needs a cloud-native workflow that is reproducible, modular, and deployable through Terraform. The workflow must support asynchronous Textract completion and preserve intermediate outputs between stages.

## Decision

Adopt an AWS serverless architecture orchestrated by Step Functions with this sequence:

1. pdf_to_jpeg Lambda
2. start_textract_job Lambda
3. export_csv Lambda

Key decision details:

- Infrastructure as code is managed with Terraform modules for S3, IAM, Lambda, database, and Step Functions.
- Separate S3 buckets are used for incoming PDFs, rendered images, Textract result artifacts, and final CSV data exports.
- A dedicated data bucket is the system-of-record sink for CSV files produced by export_csv.
- Step payloads carry predecessor outputs explicitly (for example rendered_keys and jobs with job_id).
- Textract is handled asynchronously using start_document_analysis and downstream polling via get_document_analysis until terminal status.
- CSV export is generated in export_csv from Textract analysis results and uploaded to the data bucket.

## Rationale

- Step Functions provides explicit orchestration and clear failure boundaries for each stage.
- Decoupled Lambdas keep responsibilities narrow and improve testability.
- Separate buckets reduce accidental cross-stage coupling and simplify permissions.
- Polling by job_id addresses asynchronous Textract behavior while preserving per-image traceability.
- Terraform modules provide repeatable deployment and easier evolution of resources.

## Consequences

### Positive

- End-to-end workflow is explicit and observable.
- Each Lambda can evolve independently.
- CSV outputs are centrally available in the data bucket for downstream consumers.
- IAM boundaries can be tightened by stage and bucket purpose.

### Negative

- Polling can increase Lambda runtime and cost for long-running Textract jobs.
- Additional orchestration resources increase deployment complexity.
- Current implementation still needs production hardening around retries, idempotency, and pagination guarantees.

## Rejected Alternatives

1. Script-only orchestration with cron/manual runs
- Rejected due to weak observability and limited fault handling.

2. Single monolithic Lambda for all stages
- Rejected due to timeout risk, poor separation of concerns, and hard-to-debug failures.

3. Direct synchronous extraction path only
- Rejected because Textract analysis is naturally asynchronous for this workflow.

## Operational Notes

- The export_csv Lambda writes CSV artifacts to the data bucket under an exports/ prefix.
- The export stage preserves job-level metadata to support replay and traceability.
- Future ADRs should follow this numbering convention: docs/adr/0002-*.md, docs/adr/0003-*.md, etc.

## Follow-up Work

1. Add robust pagination handling for get_document_analysis in all polling paths.
2. Move database credentials from environment variables to Secrets Manager.
3. Add dead-letter queues and retry policies for failed stages.
4. Add a second ADR for idempotency strategy and duplicate-processing prevention.
