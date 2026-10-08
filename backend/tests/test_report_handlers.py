"""Exercise the SQS and S3 event shapes without AWS network calls."""

import importlib
import json
from email import message_from_bytes


def test_builder_accepts_direct_and_sqs_events(monkeypatch, caplog):
    monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-1")
    monkeypatch.setenv("AWS_EC2_METADATA_DISABLED", "true")
    monkeypatch.setenv("REPORTS_BUCKET", "example-reports")
    builder = importlib.import_module("app.reports.lambda_handler")
    uploaded = []

    class S3:
        def put_object(self, **kwargs):
            uploaded.append(kwargs)

    async def fake_build(week):
        return week.encode()

    monkeypatch.setattr(builder, "s3", S3())
    monkeypatch.setattr(builder, "_build_and_close", fake_build)

    direct = builder.handler({"source": "schedule", "week": "2026-W40"}, None)
    sqs = builder.handler(
        {
            "Records": [
                {
                    "eventSource": "aws:sqs",
                    "body": json.dumps({"source": "report-now", "week": "2026-W39"}),
                }
            ]
        },
        None,
    )

    assert direct == {"keys": ["reports/2026-W40.csv"]}
    assert sqs == {"keys": ["reports/2026-W39.csv"]}
    assert [item["Key"] for item in uploaded] == ["reports/2026-W40.csv", "reports/2026-W39.csv"]
    assert uploaded[0]["Body"] == b"2026-W40"


def test_mailer_attaches_csv_from_s3(monkeypatch):
    monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-1")
    monkeypatch.setenv("AWS_EC2_METADATA_DISABLED", "true")
    monkeypatch.setenv("REPORT_FROM_EMAIL", "reports@example.com")
    monkeypatch.setenv("REPORT_TO_EMAILS", "recipient@example.com")
    mailer = importlib.import_module("app.reports.mailer_handler")
    sent = []

    class Body:
        def read(self):
            return b"week,meetings\n2026-W40,2\n"

    class S3:
        def get_object(self, **kwargs):
            assert kwargs == {"Bucket": "example-reports", "Key": "reports/2026-W40.csv"}
            return {"Body": Body()}

    class SES:
        def send_email(self, **kwargs):
            sent.append(kwargs)

    monkeypatch.setattr(mailer, "s3", S3())
    monkeypatch.setattr(mailer, "ses", SES())
    result = mailer.handler(
        {
            "Records": [
                {
                    "eventSource": "aws:s3",
                    "s3": {
                        "bucket": {"name": "example-reports"},
                        "object": {"key": "reports%2F2026-W40.csv"},
                    },
                }
            ]
        },
        None,
    )

    assert result == {"keys": ["reports/2026-W40.csv"]}
    assert sent[0]["Destination"] == {"ToAddresses": ["recipient@example.com"]}
    email = message_from_bytes(sent[0]["Content"]["Raw"]["Data"])
    attachment = next(part for part in email.walk() if part.get_filename() == "2026-W40.csv")
    assert attachment.get_payload(decode=True) == b"week,meetings\n2026-W40,2\n"
