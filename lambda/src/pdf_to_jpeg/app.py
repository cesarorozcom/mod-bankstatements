import os
from urllib.parse import unquote_plus

import fitz

try:
    from shared.s3_utils import make_s3_repo
except ModuleNotFoundError:
    import sys
    # Resolve the absolute path to the parent's '../shared' directory
    shared_path = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    
    if shared_path not in sys.path:
        sys.path.append(shared_path)
        
    from shared.s3_utils import make_s3_repo


s3 = make_s3_repo()


def handler(event, context):
    """Render incoming PDF pages to JPEG in an S3 bucket, supporting both S3 and Step Functions events."""
    incoming_bucket = os.environ["INCOMING_BUCKET"]
    rendered_bucket = os.environ["RENDERED_BUCKET"]

    if "Records" in event:
        records = event.get("Records", [])
        for record in records:
            bucket = record["s3"]["bucket"]["name"]
            key = unquote_plus(record["s3"]["object"]["key"])

            if bucket != incoming_bucket:
                continue

            if not key.lower().endswith(".pdf"):
                continue

            return _render_pdf(bucket, key, rendered_bucket)

        return {"status": "ignored", "event": event}

    source_bucket = event.get("source_bucket") or incoming_bucket
    source_key = event.get("source_key")
    if not source_key:
        return {"status": "ignored", "event": event}

    if not source_key.lower().endswith(".pdf"):
        return {"status": "ignored", "event": event}

    return _render_pdf(source_bucket, source_key, rendered_bucket)


def _render_pdf(bucket, key, rendered_bucket):
    download_path = "/tmp/input.pdf"
    s3.download_to_temp(bucket, key, download_path)

    pdf_document = fitz.open(download_path)
    rendered_keys = []

    for page_number in range(len(pdf_document)):
        page = pdf_document.load_page(page_number)
        zoom = 2.0
        matrix = fitz.Matrix(zoom, zoom)
        pix = page.get_pixmap(matrix=matrix, alpha=False)
        image_bytes = pix.tobytes("jpeg")

        output_key = key.replace(".pdf", f"_page_{page_number + 1}.jpg")
        s3.put_bytes(
            rendered_bucket,
            output_key,
            image_bytes,
            content_type="image/jpeg",
        )
        rendered_keys.append(output_key)

    pdf_document.close()

    return {
        "status": "ok",
        "rendered_bucket": rendered_bucket,
        # "source_key": key,
        "rendered_keys": rendered_keys,
    }


if __name__ == "__main__":
    # For local testing
    os.environ["INCOMING_BUCKET"] = "ledger-receipts-dev"
    os.environ["RENDERED_BUCKET"] = "ledger-receipts-render-dev"
    test_event = {
        "Records": [
            {
                "s3": {
                    "bucket": {"name": os.environ.get("INCOMING_BUCKET", "test-bucket")},
                    "object": {"key": "bank-statements/e_202607.pdf"},
                }
            }
        ]
    }
    print(handler(test_event, None))