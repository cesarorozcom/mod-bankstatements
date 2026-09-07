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


def handler(event, context):
    """Trigger one or more AWS Textract analysis jobs for rendered image keys."""
    rendered_bucket = _extract_rendered(event) or os.environ.get("RENDERED_BUCKET")
    textract_bucket = os.environ["TEXTRACT_BUCKET"]
    #source_bucket, source_key = _extract_source(event)
    rendered_keys = _extract_rendered_keys(event)

    if not rendered_keys:
        return {"status": "ignored", "event": event}

    jobs = []
    for key in rendered_keys:
        bucket = rendered_bucket
        response = textract.start_document_analysis(
            DocumentLocation={
                "S3Object": {
                    "Bucket": bucket,
                    "Name": key,
                }
            },
            FeatureTypes=["TABLES", "FORMS"],
            OutputConfig={
                "S3Bucket": textract_bucket,
                "S3Prefix": "results",
            },
        )
        jobs.append(
            {
                "status": "ok",
                "job_id": response["JobId"],
                "texrtract_bucket": textract_bucket,
                # Add key suffix to indicate which page/image this job corresponds to
                #"key_suffix": key.split("/")[-1],
                #"document_key": key,
            }
        )

    return {
        "status": "ok",
        "rendered_bucket": rendered_bucket,
        "rendered_keys": rendered_keys,
        "jobs": jobs,
    }


if __name__ == "__main__":
    #os.environ["RENDERED_BUCKET"] = "ledger-receipts-render-dev"
    os.environ["TEXTRACT_BUCKET"] = "ledger-receipts-textract-dev"
    os.environ["AWS_REGION"] = "us-east-1"
    # For local testing
    test_event = {'status': 'ok', 'rendered_bucket': 'ledger-receipts-render-dev', 'rendered_keys': ['bank-statements/e_202607_page_1.jpg', 'bank-statements/e_202607_page_2.jpg']}
    result = handler(test_event, None)
    print(result)