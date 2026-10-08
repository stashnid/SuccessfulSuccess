"""SQS/schedule entry point for building and storing weekly reports."""

import asyncio
import json
import logging
import os

import boto3
from app.db import engine
from app.reports.weekly import build_weekly_report, previous_iso_week, report_key

log = logging.getLogger(__name__)
log.setLevel(logging.INFO)
s3 = boto3.client("s3")


async def _build_and_close(week: str) -> bytes:
    try:
        return await build_weekly_report(week)
    finally:
        # Lambda may reuse this process with a new asyncio.run() event loop.
        await engine.dispose()


def _requests(event: dict) -> list[tuple[str, str, str | None]]:
    records = event.get("Records")
    if records:
        requests = []
        for record in records:
            if record.get("eventSource") != "aws:sqs":
                raise ValueError("expected an SQS record")
            body = json.loads(record["body"])
            requests.append(("sqs", body.get("source", "unknown"), body.get("week")))
        return requests
    return [("schedule", event.get("source", "schedule"), event.get("week"))]


def handler(event: dict, _context: object) -> dict:
    bucket = os.environ["REPORTS_BUCKET"]
    built = []
    for trigger, source, requested_week in _requests(event):
        week = requested_week or previous_iso_week()
        key = report_key(week)
        log.info("report-builder triggered trigger=%s source=%s week=%s", trigger, source, week)
        content = asyncio.run(_build_and_close(week))
        s3.put_object(Bucket=bucket, Key=key, Body=content, ContentType="text/csv; charset=utf-8")
        log.info("report-builder stored bucket=%s key=%s", bucket, key)
        built.append(key)
    return {"keys": built}
