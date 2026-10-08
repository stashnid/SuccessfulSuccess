# Lab 5 submission notes

## Deployed architecture

The Free-plan account cannot create the private Aurora cluster described in the
assignment. With the lecturer's permission to use a working alternative, the
existing CloudFront/ECS/Supabase application remains live. The weekly report
runs on AWS: EventBridge Scheduler -> SQS -> builder Lambda -> private S3 CSV ->
S3 ObjectCreated -> mailer Lambda -> SES. The builder reads the same Supabase
PostgreSQL database as the app, through the pooler. Both Lambdas are outside a
VPC, so there is no NAT gateway or VPC endpoint charge.

The schedule is `cron(0 7 ? * MON *)` in `Europe/Kyiv`. A temporary one-minute
test schedule caused several identical emails during deployment; it was removed.
The regular schedule now targets SQS. The report bucket contains at least
`reports/2026-W39.csv` and `reports/2026-W40.csv`.

On 2026-10-08 the controlled verification produced these CloudWatch entries
(timestamps UTC):

```text
11:05:07 report-builder triggered trigger=sqs source=report-now week=2026-W39
11:09:27 report-builder triggered trigger=schedule source=schedule week=2026-W40
11:09:29 report-mailer triggered trigger=s3 bucket=successfulsuccess-reports-312209831599 key=reports/2026-W40.csv
11:09:30 report-mailer sent trigger=s3 key=reports/2026-W40.csv recipients=1
```

The one-time schedule used for the schedule-trigger check had
`ActionAfterCompletion=DELETE` and was confirmed absent after execution.
The production schedule remained enabled for Mondays at 07:00 Kyiv time.

## Evidence to submit

- Link to the commit containing the report code, two handlers, CloudFormation
  template, and this note.
- Screenshot of a delivered SES email with its CSV attachment (the recipient is
  the verified student address).
- Output of `make report-objects` showing at least two report keys.
- CloudWatch lines showing `trigger=schedule`, `trigger=sqs`, and `trigger=s3`.

## Part 3, Step 7: short answers

**Duplicate email:** S3 ObjectCreated notifications are delivered at least once.
Rebuilding the same week overwrites the same S3 key but creates a new upload
notification. The CSV filename is idempotent; sending the email is not. A
persistent conditional-write record keyed by `(report week, recipient, report
version)` could suppress repeats. A crash between marking the record and SES
accepting the message needs an explicit retry/reconciliation policy; exactly
once delivery cannot be assumed from S3 notifications alone.

**VPC access to SES:** For a VPC-attached builder, a NAT gateway offers general
internet access but has an hourly and data-processing charge. A PrivateLink
interface endpoint for SES SMTP has an hourly charge per availability zone and
requires SMTP integration; it is not a drop-in network path for the SES v2 HTTPS
API. A separate mailer Lambda outside the VPC has no idle network cost and is
appropriate for roughly ten extra emails a week. At a million emails a week,
SES sending quotas, per-email pricing, batching and deduplication dominate the
choice; a dedicated mailer fleet would need load testing and an explicit cost
comparison. The deployed alternative also has the builder outside a VPC because
its database is Supabase.

**One-week download link:** A presigned S3 URL made with a Lambda role's temporary
credentials can expire before seven days. Put the private report bucket behind
CloudFront and issue a CloudFront signed URL or cookie with a seven-day policy,
using a managed key pair and a distribution that only allows authorized report
access.

## Other discussion points

- The schedule and `make report-now` send commands to SQS. S3 ObjectCreated is an
  event saying a report already exists. The builder need not know who listens.
- SQS buffers bursts, retries failed work and moves repeated failures to a DLQ.
  Its visibility timeout exceeds the Lambda timeout so another worker cannot
  start the same report before the first normally finishes. A CloudWatch alarm
  watches visible messages in the DLQ.
- A report is a snapshot of the database at build time. An edit at 07:01 after
  the 07:00 run requires rebuilding that week; an automatic five-minute refresh
  would need an additional calendar-change trigger and would send more emails
  unless notification deduplication is added.
- RabbitMQ with durable queues and acknowledgements is a better self-hosted
  broker than a plain Redis list when losing a payment event is unacceptable.
  RQ's pickled function path can break queued jobs after a function is renamed;
  versioned data messages are safer between services. Two Celery beat instances
  could each emit the same schedule, while one managed EventBridge schedule is
  configured as a single AWS resource.
