"""Textract helper utilities shared across Lambda functions."""

import os
import boto3


def _get_textract_client():
    return boto3.client("textract", region_name=os.environ.get("AWS_REGION"))


def fetch_all_document_analysis(job_id: str, client=None) -> dict:
    """Fetch and merge all pages of a Textract GetDocumentAnalysis result.

    Textract paginates results via NextToken. This function collects all
    blocks across pages and returns a single merged response dict whose
    ``Blocks`` list contains every block from every page.

    Args:
        job_id: The Textract job ID returned by StartDocumentAnalysis.
        client: Optional pre-built boto3 Textract client (useful for testing).

    Returns:
        A dict shaped like a single GetDocumentAnalysis response, with all
        blocks accumulated under the ``Blocks`` key.
    """
    textract = client or _get_textract_client()

    response = textract.get_document_analysis(JobId=job_id)
    all_blocks = list(response.get("Blocks", []))

    while response.get("NextToken"):
        response = textract.get_document_analysis(
            JobId=job_id, NextToken=response["NextToken"]
        )
        all_blocks.extend(response.get("Blocks", []))

    response["Blocks"] = all_blocks
    return response
