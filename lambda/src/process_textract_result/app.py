"""Phase 2 of the document workflow: react to Textract job completion.

Amazon Textract publishes one completion message per asynchronous job to an
SNS topic (configured as the job's NotificationChannel). This Lambda subscribes
to that topic. For each completed job it validates the status and, on success,
invokes the export_csv Lambda directly with the job details.

This replaces the Step Functions polling loop: completion is event-driven, so
no state-machine transitions are spent waiting for Textract.

Expected SNS message body (Textract async notification):
    {
        "JobId": "...",
        "Status": "SUCCEEDED" | "FAILED" | "ERROR",
        "API": "StartDocumentAnalysis",
        "JobTag": "...",
        "Timestamp": 1234567890,
        "DocumentLocation": {"S3ObjectName": "...", "S3Bucket": "..."}
    }
"""

import json
import os

import boto3

_lambda = boto3.client("lambda", region_name=os.environ.get("AWS_REGION"))

SUCCESS_STATUSES = {"SUCCEEDED", "PARTIAL_SUCCESS"}


def _iter_textract_notifications(event):
    """Yield each Textract completion notification dict from an SNS event.

    Handles the standard SNS -> Lambda envelope (Records[].Sns.Message), and
    also accepts a raw notification dict for direct/local invocation.
    """
    records = event.get("Records")
    if records:
        for record in records:
            message = record.get("Sns", {}).get("Message")
            if not message:
                continue
            try:
                yield json.loads(message)
            except (TypeError, ValueError):
                continue
        return

    # Direct invocation / local test: the event is the notification itself.
    if event.get("JobId"):
        yield event


def _invoke_export_csv(job):
    function_name = os.environ["EXPORT_CSV_FUNCTION"]
    _lambda.invoke(
        FunctionName=function_name,
        InvocationType="Event",  # async, fire-and-forget
        Payload=json.dumps({"jobs": [job]}).encode("utf-8"),
    )


def handler(event, context):
    processed = []
    for note in _iter_textract_notifications(event):
        job_id = note.get("JobId")
        status = note.get("Status")

        if status not in SUCCESS_STATUSES:
            # FAILED / ERROR: nothing to export. Surface it in logs and skip.
            print(f"Textract job {job_id} did not succeed: status={status}")
            processed.append({"job_id": job_id, "status": status, "action": "skipped"})
            continue

        doc = note.get("DocumentLocation", {})
        job = {
            "status": "ok",
            "job_id": job_id,
            "textract_bucket": doc.get("S3Bucket"),
            "rendered_key": doc.get("S3ObjectName"),
        }
        _invoke_export_csv(job)
        processed.append({"job_id": job_id, "status": status, "action": "export_invoked"})

    return {"status": "ok", "processed": processed}


