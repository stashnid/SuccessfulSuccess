"""S3 notification entry point for emailing a completed CSV report."""

import logging
import os
from email.message import EmailMessage
from urllib.parse import unquote_plus

import boto3

log = logging.getLogger(__name__)
log.setLevel(logging.INFO)
s3 = boto3.client("s3")
ses = boto3.client("sesv2")


def handler(event: dict, _context: object) -> dict:
    sender = os.environ["REPORT_FROM_EMAIL"]
    recipients = [
        item.strip() for item in os.environ["REPORT_TO_EMAILS"].split(",") if item.strip()
    ]
    if not recipients:
        raise ValueError("REPORT_TO_EMAILS is empty")
    sent = []
    for record in event["Records"]:
        if record.get("eventSource") != "aws:s3":
            raise ValueError("expected an S3 notification")
        bucket = record["s3"]["bucket"]["name"]
        key = unquote_plus(record["s3"]["object"]["key"])
        if not key.startswith("reports/") or not key.endswith(".csv"):
            continue
        log.info("report-mailer triggered trigger=s3 bucket=%s key=%s", bucket, key)
        report = s3.get_object(Bucket=bucket, Key=key)["Body"].read()
        message = EmailMessage()
        message["From"] = sender
        message["To"] = ", ".join(recipients)
        message["Subject"] = (
            f"Weekly meetings report: {key.removeprefix('reports/').removesuffix('.csv')}"
        )
        message.set_content("Your weekly meetings report is attached as a CSV file.")
        message.add_attachment(
            report, maintype="text", subtype="csv", filename=key.rsplit("/", 1)[1]
        )
        ses.send_email(
            FromEmailAddress=sender,
            Destination={"ToAddresses": recipients},
            Content={"Raw": {"Data": message.as_bytes()}},
        )
        log.info("report-mailer sent trigger=s3 key=%s recipients=%d", key, len(recipients))
        sent.append(key)
    return {"keys": sent}
