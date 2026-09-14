"""Stage 1 of the document workflow: render PDF pages to JPEG images.

This Lambda is the first task in the Step Functions state machine. It reads an
incoming PDF from S3, renders each page to a JPEG using PyMuPDF (fitz), and
writes the images to the rendered bucket. The returned rendered_keys are passed
to the next stage (start_textract_job).

Event shapes accepted:
- Step Functions input: {"source_bucket": "...", "source_key": "incoming/x.pdf"}
- Raw S3 event: {"Records": [{"s3": {"bucket": {"name": ...}, "object": {"key": ...}}}]}

Environment variables:
- INCOMING_BUCKET: bucket holding the source PDFs.
- RENDERED_BUCKET: bucket the rendered JPEGs are written to.
"""

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
    """Render incoming PDF pages to JPEG in S3.

    Supports both a direct S3 event (Records) and a Step Functions input
    carrying source_bucket/source_key. Non-PDF keys or missing keys are
    ignored. Returns the rendered bucket and the list of rendered page keys.
    """
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
    """Download one PDF, render every page to a JPEG, and upload them.

    Each page is rendered at 2x zoom for higher OCR fidelity and written to
    rendered_bucket as ``<original_key_without_.pdf>_page_<n>.jpg``. Returns a
    status dict with the rendered bucket and the ordered list of page keys.
    """
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


