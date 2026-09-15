"""S3 helper utilities shared across Lambda functions."""

import boto3


class S3Repo:
    def __init__(self, client=None):
        self._s3 = client or boto3.client("s3")

    def download_to_temp(self, bucket: str, key: str, destination: str) -> None:
        """Download an S3 object to a local path."""
        self._s3.download_file(bucket, key, destination)

    def put_bytes(
        self,
        bucket: str,
        key: str,
        data: bytes,
        content_type: str = "application/octet-stream",
    ) -> None:
        """Upload raw bytes to S3."""
        self._s3.put_object(Bucket=bucket, Key=key, Body=data, ContentType=content_type)

    def write_text(
        self,
        bucket: str,
        key: str,
        text: str,
        content_type: str = "text/plain; charset=utf-8",
    ) -> None:
        """Upload a UTF-8 string to S3."""
        self._s3.put_object(
            Bucket=bucket,
            Key=key,
            Body=text.encode("utf-8"),
            ContentType=content_type,
        )


def make_s3_repo(client=None) -> S3Repo:
    """Factory that returns an S3Repo instance."""
    return S3Repo(client=client)
