# ADR 0003: Decoupled Two-Phase Textract Completion via SNS

- Status: Accepted
- Date: 2026-09-14
- Deciders: Project maintainers
- Technical story: Remove the Step Functions polling loop that consumed too many state transitions, while still ensuring export_csv runs only after asynchronous Textract jobs finish.

## Context

An earlier, short-lived design moved Textract completion polling into the state machine as a Map with a WaitForJob -> GetJobStatus -> CheckJobStatus loop. That fixed the ordering defect but was transition-heavy: Standard Workflows bill per state transition, and each poll cycle is three transitions, repeated per job until the job reaches a terminal state. That polling design was replaced before this ADR and is not retained as its own record.

For this project the practical per-execution transition budget is tight (target around 32, aligned with free-tier usage expectations). A multi-page document polled at a 15-second interval easily exceeds that. The polling loop, not the workflow itself, was the cost driver.

## Decision

Split the workflow into two phases and make completion event-driven, removing the polling loop entirely.

### Phase 1 (Step Functions)

The state machine is reduced to:

1. PdfToJpeg (Task)
2. StartTextractJob (Task), which is now the terminal state.

start_textract_job calls start_document_analysis with a NotificationChannel pointing at an SNS topic and a publish role. It returns immediately after starting the jobs. Phase 1 is about two state transitions per execution regardless of Textract duration or page count.

### Phase 2 (event-driven, no Step Functions)

1. Textract publishes one completion message per job to the SNS topic (fields include JobId, Status, DocumentLocation).
2. process_textract_result is subscribed to the topic. For each SUCCEEDED or PARTIAL_SUCCESS job it invokes export_csv asynchronously (InvocationType Event) with that job; FAILED/ERROR jobs are logged and skipped.
3. export_csv fetches the analysis results and writes the CSV to the data bucket, unchanged from before.

### Supporting infrastructure

- A new Terraform messaging module owns the SNS topic (project-env-textract-completion) and the role Textract assumes to publish (project-env-textract-publish).
- The shared Lambda execution role gains scoped iam:PassRole for the Textract publish role (conditioned on iam:PassedToService = textract.amazonaws.com) and lambda:InvokeFunction scoped to the export_csv function.
- The Step Functions role no longer needs textract:GetDocumentAnalysis; that policy was removed. The export_csv ARN was removed from the state machine invoke policy since the state machine no longer invokes it.

## Rationale

- Phase 1 transitions are constant and small, fitting the free-tier transition budget with wide margin.
- Wait/poll transitions are eliminated; completion latency is driven by Textract plus SNS/Lambda delivery, not a fixed poll interval.
- The design uses the notification mechanism async Textract is built around, rather than emulating synchronous behavior.
- Phase 2 uses Lambda and SNS only, so it consumes zero Step Functions transitions.

## Consequences

### Positive

- Transition cost per document no longer scales with Textract job duration or page count.
- export_csv still only runs on completed jobs; the original ordering defect stays fixed.
- Components are loosely coupled and independently testable.

### Negative

- More infrastructure than a single state machine: an SNS topic, a Textract publish role, a subscription, and an invoke permission.
- Loss of single-execution traceability: completion no longer appears in one Step Functions execution history. Correlation relies on JobId across CloudWatch logs.
- export_csv runs once per job (per page), producing one CSV per page under exports/{job_id}.csv. Consolidating to one CSV per document would require a separate aggregation step.
- No built-in retry/DLQ yet on the SNS -> Lambda path (see Follow-up Work).

## Rejected Alternatives

1. Express Workflow running the same polling loop
- Express is not billed per transition, but has a hard 5-minute execution cap. Slow Textract jobs would exceed it. Rejected as fragile.

2. Single state machine with StartTextractJob using .waitForTaskToken
- Minimal transitions and keeps one execution/traceable history, but requires a completion Lambda that maps SNS notifications back to task tokens per job. More coupling than needed given one job per page. Rejected in favor of the simpler decoupled path; may be revisited if single-execution traceability becomes important.

3. Keep the in-state-machine polling loop
- Rejected: exceeds the transition budget.

## Operational Notes

- SNS message shape consumed by process_textract_result: JobId, Status, API, JobTag, Timestamp, DocumentLocation{S3ObjectName, S3Bucket}.
- start_textract_job only attaches a NotificationChannel when TEXTRACT_SNS_TOPIC_ARN and TEXTRACT_PUBLISH_ROLE_ARN are set, so local runs still start jobs without notifications.
- process_textract_result invokes the function named by EXPORT_CSV_FUNCTION using async (Event) invocation.

## Follow-up Work

1. Add a dead-letter queue and retry policy for the SNS -> process_textract_result -> export_csv path.
2. Consider an aggregation step to produce a single consolidated CSV per source document.
3. Revisit .waitForTaskToken if single-execution traceability is later required.
4. Carry forward remaining items from ADR 0001 (pagination, Secrets Manager for credentials).
