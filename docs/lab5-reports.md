# Weekly reports laboratory: Free plan deployment

The current website runs on CloudFront, ECS and Supabase. This lab keeps that
working application and adds the AWS event-driven reporting path separately:

`EventBridge Scheduler or make report-now -> SQS -> report-builder Lambda ->
S3 reports/<ISO-week>.csv -> S3 ObjectCreated -> report-mailer Lambda -> SES`.

The account's Free plan rejected the earlier private Aurora stack with
`WithExpressConfiguration` required. The lecturer permits an alternative
architecture when the complete feature works. Therefore the builder reads the
existing Supabase PostgreSQL database through its IPv4 session pooler. Both
Lambda functions run outside a VPC, so they need neither NAT nor an S3 gateway
endpoint. The website and ECS API continue to use the same database. The
unusable private-Aurora template remains in `infra/backend.yml` as a record of
the original lab design; it is not deployed on this account.

The builder's database URL is stored under the `url` key in the existing
Secrets Manager secret `successfulsuccess-db-credentials`. The Lambda receives
only that secret's ARN and has permission to read only that secret. Never copy
the URL into CloudFormation parameters, Git, logs or screenshots. The existing
ECS task also has a database URL and should be migrated to a secret in a
separate hardening change.

## Behavior

The schedule sends `{"week":null,"source":"schedule"}` each Monday at
07:00 Europe/Kyiv. The builder chooses the preceding ISO week. Manual requests
use `make report-now WEEK=2026-W40` and an explicit week. Each week has one S3
key, so replay overwrites the CSV, but S3 emits another ObjectCreated event and
SES can send a second email. SQS retries failed builds three times before the
dead-letter queue. Report files expire after 90 days; the bucket is retained
if its stack is deleted.

The SES sender and recipient are the same verified email address while the
account remains in the SES sandbox. No custom domain is required for this lab.

## Deployment inputs

- ECR image built from `backend/Dockerfile.lambda`, pinned by digest.
- The existing database secret ARN, with `url` holding the current pooler URL.
- A private S3 artifact bucket containing the mailer zip at an immutable key.
- A verified SES sender and recipient in `us-east-1`.

`infra/reports.yml` creates the report bucket, queue and DLQ, Lambda functions,
schedule, S3 notification, IAM roles, seven-day log retention, and a DLQ alarm.

## Verification and submission evidence

1. Test the CSV builder locally against PostgreSQL.
2. Deploy with a temporary direct schedule (`ScheduleTarget=LAMBDA`,
   `ScheduleExpression=rate(5 minutes)`) to capture a `trigger=schedule` log.
3. Switch the schedule to SQS. Capture a `trigger=sqs source=schedule` log, then
   restore the Monday cron expression.
4. Run `make report-now WEEK=<different-week>` and check that S3 has two report
   keys, builder logs show `trigger=sqs source=report-now`, mailer logs show
   `trigger=s3`, and SES delivered the CSV attachment. Take an inbox screenshot.
5. Exercise the DLQ and replay path without leaving failure injection enabled.
   Send the same week twice and explain why duplicate email is possible.

Submit the commit link, inbox screenshot, recursive S3 listing with both
reports, three CloudWatch trigger lines, and short Part 3 Step 7 answers.
Explain in the write-up that the deployed builder is outside a VPC because it
reads Supabase; the assignment's Aurora network-cost comparison remains a
design discussion rather than a claim about the deployed topology.
