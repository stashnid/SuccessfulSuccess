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
The regular schedule now targets SQS. The report bucket contains four weekly
CSV objects, including one created by the production Monday schedule.

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
On Monday 2026-10-12 it ran without intervention: the builder logged
`trigger=sqs source=schedule week=2026-W41` at 04:00:03 UTC, S3 stored
`reports/2026-W41.csv` at 04:00:06 UTC, and the mailer logged `trigger=s3`
and `sent ... recipients=1` at 04:00:07 UTC. The CSV has one meeting totalling
one hour, a previous-week comparison, one longest-meeting row and one
per-person row.

The recursive S3 listing after the automatic run and the failure-recovery test
was:

```text
2026-10-14 16:33:14  184  reports/2026-W38.csv
2026-10-08 14:05:10  184  reports/2026-W39.csv
2026-10-08 14:09:28  184  reports/2026-W40.csv
2026-10-12 07:00:06  340  reports/2026-W41.csv
```

W39 was requested with `make report-now`; W41 was built by the regular
schedule. The timestamp display above is in the local Kyiv timezone.

## Failure recovery test (2026-10-14)

For a controlled test, the builder's database-secret ARN was temporarily set
to a nonexistent value and one request for W38 was queued. CloudWatch recorded
three failed delivery attempts at 13:15, 13:21 and 13:27 UTC. SQS then moved
that request to the dead-letter queue. The real secret ARN was restored before
the single message was redriven to the main queue. Its move task completed
with `ApproximateNumberOfMessagesMoved=1`; the DLQ returned to zero visible
messages. The builder then logged
`trigger=sqs source=dlq-recovery-test week=2026-W38` at 13:33:12 UTC and
stored `reports/2026-W38.csv` at 13:33:13. The mailer logged `trigger=s3`
at 13:33:15 and `sent ... recipients=1` at 13:33:16. The Lambda's actual
database-secret ARN was verified restored. The DLQ CloudWatch alarm has the
SNS topic as an alarm action. The operator confirmed its email subscription
on 2026-10-14, and the alarm returned to `OK` at 16:40 Kyiv time after the
queue emptied.

## Evidence to submit

- Link to the commit containing the report code, two handlers, CloudFormation
  template, and this note.
- Screenshot of a delivered SES email with its CSV attachment (the recipient is
  the verified student address).
- Output of `make report-objects` showing at least two report keys.
- CloudWatch lines showing `trigger=schedule`, `trigger=sqs`, and `trigger=s3`.
- The failure-recovery log lines above, if the lecturer asks for the DLQ test.

## Part 3, Step 7: short answers

**Duplicate email:** S3 ObjectCreated notifications are delivered at least once.
Rebuilding the same week overwrites the same S3 key but creates a new upload
notification. The CSV filename is idempotent; sending the email is not. A
persistent conditional-write record keyed by `(report week, recipient, report
version)` could suppress repeats. A crash between marking the record and SES
accepting the message needs an explicit retry/reconciliation policy; exactly
once delivery cannot be assumed from S3 notifications alone.

**VPC access to SES:** A NAT gateway provides general internet access. At an
illustrative $0.045 per hour, one gateway running for 30 days costs about $32.40
before data processing and transfer. A PrivateLink interface endpoint for SES
costs about $0.01 per hour per availability zone, so one zone is about $7.20
or two zones about $14.40 for 30 days, plus processed data. Current SES
documentation supports both SMTP and API interface endpoints; an API endpoint
can carry the existing SES v2 HTTPS call. The deployed split puts the mailer
outside the VPC and adds **$0 fixed network cost**; Lambda execution and SES
sending still have usage charges. For ten extra emails a week I would keep the
split. For a million a week I would still separate report building from mail
delivery, then test throughput, request production SES access, set quotas and
deduplicate retries. At $0.10 per 1,000 outbound messages, a million emails
per week is roughly $400 for four weeks before attachment data and other
services. The deployed builder is also outside a VPC because its database is
Supabase. [NAT pricing](https://aws.amazon.com/vpc/pricing/),
[PrivateLink pricing](https://aws.amazon.com/privatelink/pricing/),
[SES VPC endpoint support](https://docs.aws.amazon.com/ses/latest/dg/send-email-set-up-vpc-endpoints.html),
[SES pricing](https://aws.amazon.com/ses/pricing/).

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
