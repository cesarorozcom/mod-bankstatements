import csv
import io
import os
import time
from datetime import date, datetime as dt
from urllib.parse import quote_plus
from typing import Any, Dict, List

import boto3
from trp import Document

try:
    from shared.s3_utils import make_s3_repo
except ModuleNotFoundError:
    import sys

    shared_path = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    if shared_path not in sys.path:
        sys.path.append(shared_path)
    from shared.s3_utils import make_s3_repo


try:
    from shared.textract_utils import fetch_all_document_analysis
except ModuleNotFoundError:
    import sys
    # Resolve the absolute path to the parent's '../shared' directory
    shared_path = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    
    if shared_path not in sys.path:
        sys.path.append(shared_path)
        
    from shared.textract_utils import fetch_all_document_analysis

DATE_FORMAT = "%d-%m-%Y"

s3 = make_s3_repo()

def _extract_jobs(event: Dict[str, Any]) -> List[Dict[str, Any]]:
    if event.get("jobs"):
        return event["jobs"]
    if event.get("job_id"):
        return [event]
    return []


def _csv_from_response(response: Dict[str, Any]) -> List[Dict[str, Any]]:
    doc = Document(response)
    exported = []
    #buffer = io.StringIO()
    #writer = csv.DictWriter(buffer, fieldnames=["movement_id", "operation_date", "value_date", "description", "credits", "debit", "balance"])

    for page_num, page in enumerate(doc.pages, start=1):
        for table_num, table in enumerate(page.tables, start=1):
            buffer = io.StringIO()
            writer = csv.writer(buffer)

            for row in table.rows:
                row_data = [cell.text.strip() if cell.text else "" for cell in row.cells]

                if len(row_data) >= 7:
                    # Skip header rows
                    if "Movi" in row_data[0] or "Fecha" in row_data[0]:
                    # Skip header rows
                        continue
                    
                    if any(cell == "" for cell in row_data[0:2]):
                    # Skip rows with missing essential data
                        continue

                    writer.writerow(
                        [
                            (cell.text or "").strip() if cell else ""
                            for cell in row.cells
                        ]
                    )
            exported.append(buffer.getvalue())
            """
            exported.append(
                {
                    "page_number": page_num,
                    "table_number": table_num,
                    "csv": buffer.getvalue(),
                }
            )
            

    
    """
    return exported

def _extract_movements_from_document(response):
    doc = Document(response)
    movements = []
    for page in doc.pages:
        for table in page.tables:
            for row in table.rows:
                row_data = [cell.text.strip() if cell.text else "" for cell in row.cells]
                if len(row_data) < 7:
                    continue
                if "Movi" in row_data[0] or "Fecha" in row_data[0]:
                    continue
                if any(cell == "" for cell in row_data[0:2]):
                    continue
                try:
                    movement = {
                        "movement_id": int(row_data[0]) if row_data[0].isdigit() else 0,
                        "operation_date": dt.strptime(row_data[1], DATE_FORMAT).date().isoformat() if row_data[1] else None,
                        "value_date": dt.strptime(row_data[2], DATE_FORMAT).date().isoformat() if row_data[2] else None,
                        "description": row_data[3],
                        "credits": float(row_data[4].replace(",", "")) if row_data[4] else 0.0,
                        "debit": float(row_data[5].replace(",", "")) if row_data[5] else 0.0,
                        "balance": float(row_data[6].replace(",", "")) if row_data[6] else 0.0,
                    }
                    movements.append(movement)
                except (TypeError, ValueError):
                    continue
    return movements


def _wait_for_analysis(textract_client, job_id, max_attempts=30, poll_seconds=5):
    for _ in range(max_attempts):
        response = textract_client.get_document_analysis(JobId=job_id)
        status = response.get("JobStatus")
        if status in {"SUCCEEDED", "PARTIALLY_SUCCEEDED"}:
            return response
        if status in {"FAILED", "CANCELED", "ABORTED"}:
            raise RuntimeError(f"Textract analysis failed for job {job_id}: {status}")
        time.sleep(poll_seconds)
    raise TimeoutError(f"Textract job {job_id} did not complete within the polling window")


def handler(event, context):
    jobs = _extract_jobs(event)
    if not jobs:
        return {"status": "ignored", "reason": "no_jobs", "event": event}

    exports = []
    fields_names = ["movement_id", "operation_date", "value_date", "description", "credits", "debit", "balance"]
    for job in jobs:
        job_id = job["job_id"]
        buffer = io.StringIO()
        writer = csv.DictWriter(buffer, fieldnames=fields_names)
        writer.writeheader()

        response = fetch_all_document_analysis(job_id)
        movements = _extract_movements_from_document(response)
        for movement in movements:
            writer.writerow(movement)

        
        s3.write_text(
            bucket=os.environ["DATA_BUCKET"],
            key=f"exports/{job_id}.csv",
            text=buffer.getvalue()
        )
        
    """ 
        exports.append(
            {
                "job_id": job_id,
                "rendered_key": job.get("rendered_key"),
                "tables": _csv_from_response(response),
            }
        )
       
    s3.write_text(
        bucket=os.environ["DATA_BUCKET"],
        key=f"exports/export_{dt.now().strftime('%Y%m%d_%H%M%S')}.csv",
        text=str(exports)
    )
        s3.write_text(
        bucket=os.environ["DATA_BUCKET"],
        key=f"exports/export_{dt.now().strftime('%Y%m%d_%H%M%S')}.csv",
        text=exports,
        content_type="text/csv",
    )
    """

    return {
        "status": "ok",
    }

if __name__ == "__main__":
    os.environ["AWS_REGION"] = "us-east-1"
    os.environ["DATA_BUCKET"] = "ledger-receipts-data-dev"
    # For local testing
    test_event = {'status': 'ok', 'jobs': [{'status': 'ok', 'job_id': '94f08eb48bb45976a8ad72e05fb90e62c4d1787344ef4e0d6f3d865518a68220', 'texrtract_bucket': 'ledger-receipts-textract-dev'}, {'status': 'ok', 'job_id': 'd50d06c7c7885cb6775d33129d673d794186846914e30744f2cb868748406d87', 'texrtract_bucket': 'ledger-receipts-textract-dev'}]}
    print(handler(test_event, None))