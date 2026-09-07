import importlib.util
import os
import unittest


module_path = os.path.join(os.path.dirname(__file__), "app.py")
spec = importlib.util.spec_from_file_location("export_csv_app", module_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ExportCsvPollingTest(unittest.TestCase):
    def test_export_csv_polls_for_completed_job(self):
        calls = []

        class FakeTextract:
            def __init__(self):
                self._statuses = [
                    {"JobStatus": "IN_PROGRESS"},
                    {"JobStatus": "SUCCEEDED", "Blocks": []},
                ]

            def get_document_analysis(self, JobId):
                calls.append(JobId)
                return self._statuses.pop(0)

        fake_client = FakeTextract()
        original_client = module.boto3.client
        module.boto3.client = lambda *args, **kwargs: fake_client
        try:
            event = {
                "jobs": [{"job_id": "job-123"}],
                "source_bucket": "ledger-receipts-dev",
                "source_key": "bank-statements/e_202607.pdf",
            }
            result = module.handler(event, None)
        finally:
            module.boto3.client = original_client

        self.assertEqual(calls, ["job-123", "job-123"])
        self.assertEqual(result["status"], "ok")
        self.assertEqual(result["job_ids"], ["job-123"])


if __name__ == "__main__":
    unittest.main()
