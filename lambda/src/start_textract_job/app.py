import os
from urllib.parse import unquote_plus

import boto3

try:
    from shared.s3_utils import make_s3_repo
except ModuleNotFoundError:
    import sys
    # Resolve the absolute path to the parent's '../shared' directory
    shared_path = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    
    if shared_path not in sys.path:
        sys.path.append(shared_path)
        
    from shared.s3_utils import make_s3_repo


textract = boto3.client("textract", region_name=os.environ["AWS_REGION"])
s3 = make_s3_repo()


def _extract_rendered_keys(event):
    if "rendered_keys" in event:
        return event["rendered_keys"]

    if "rendered_keys" in event["pdf_to_jpeg_result"]:
        return event["rendered_keys"]

    if "Records" in event:
        records = event.get("Records", [])
        rendered_keys = []
        for record in records:
            bucket = record.get("s3", {}).get("bucket", {}).get("name")
            key = unquote_plus(record.get("s3", {}).get("object", {}).get("key", ""))
            if bucket and key:
                rendered_keys.append(key)
        return rendered_keys

    return []


def _extract_rendered(event):
    if "rendered_bucket" in event:
        return event["rendered_bucket"]
    #if "pdf_to_jpeg_result" in event:
    #    result = event["pdf_to_jpeg_result"]
    #    return result.get("source_bucket"), result.get("source_key", "")
    #return os.environ.get("RENDERED_BUCKET"), ""


def _notification_channel():
    """Build the NotificationChannel so Textract publishes completion to SNS.

    Returns None when the topic/role env vars are absent (e.g. local runs),
    so the job still starts without notifications.
    """
    topic_arn = os.environ.get("TEXTRACT_SNS_TOPIC_ARN")
    role_arn = os.environ.get("TEXTRACT_PUBLISH_ROLE_ARN")
    if topic_arn and role_arn:
        return {"SNSTopicArn": topic_arn, "RoleArn": role_arn}
    return None


def handler(event, context):
    """Trigger one or more AWS Textract analysis jobs for rendered image keys.

    Each job is started asynchronously with a NotificationChannel so Textract
    publishes a completion message to SNS. Downstream completion handling
    (process_textract_result -> export_csv) is driven by that notification, so
    this function returns immediately after starting the jobs.
    """
    rendered_bucket = _extract_rendered(event) or os.environ.get("RENDERED_BUCKET")
    textract_bucket = os.environ["TEXTRACT_BUCKET"]
    rendered_keys = _extract_rendered_keys(event)

    if not rendered_keys:
        return {"status": "ignored", "event": event}

    notification_channel = _notification_channel()

    jobs = []
    for key in rendered_keys:
        bucket = rendered_bucket
        params = {
            "DocumentLocation": {
                "S3Object": {
                    "Bucket": bucket,
                    "Name": key,
                }
            },
            "FeatureTypes": ["TABLES", "FORMS"],
            "OutputConfig": {
                "S3Bucket": textract_bucket,
                "S3Prefix": "results",
            },
        }
        if notification_channel:
            params["NotificationChannel"] = notification_channel

        response = textract.start_document_analysis(**params)
        jobs.append(
            {
                "status": "ok",
                "job_id": response["JobId"],
                "textract_bucket": textract_bucket,
                "rendered_bucket": rendered_bucket,
                "rendered_key": key,
            }
        )

    return {
        "status": "ok",
        "rendered_bucket": rendered_bucket,
        "rendered_keys": rendered_keys,
        "jobs": jobs,
    }


