# Weekly reports laboratory: implementation and deployment

The checked-in `infra/reports.yml` is a **new** stack for the Lambda + Aurora
architecture required by the assignment. The former deployment is ECS/ALB +
Supabase. Deploy `infra/backend.yml` in parallel, apply its migrations, transfer
the existing rows with `scripts/migrate-ecs-data.py`, and verify the new API
before pointing the website at it. Keep the old ECS service until the cutover
has been checked.

## Account limitation observed on 2026-10-08

The AWS account is on the Free plan. A CloudFormation change set for the
private Aurora cluster was accepted, but RDS rejected creation with
`To use Aurora clusters with free plan accounts you need to set
WithExpressConfiguration`. Aurora Express has no VPC association and uses IAM
authentication through an internet gateway, so it cannot serve as the private
VPC/Aurora prerequisite described by this lab. The failed stack was rolled
back and removed; no Aurora cluster was created. The generated database secret
was retained and can be reused by passing its ARN as `ExistingDbSecretArn`
after the account can create a full-configuration cluster.

The Lambda image is already in the `spry-backend` ECR repository under the
`lab5-reports` tag. The mailer zip is in the private
`successfulsuccess-artifacts-312209831599` bucket. The sender email identity
is verified in SES, but the account is still in the SES sandbox. The reports
stack has not been deployed because it depends on the backend stack.

## Event flow

`Scheduler -> SQS -> report-builder (VPC/Aurora) -> S3 reports/<ISO-week>.csv
-> S3 ObjectCreated -> report-mailer (outside VPC) -> SES`.

The schedule sends `{"week":null,"source":"schedule"}`. The builder chooses
the previous ISO week in Europe/Kyiv. `make report-now WEEK=2026-W39` sends the
same command shape with an explicit week and `source=report-now`. Each week has
one object key; replay overwrites it, but S3 emits another ObjectCreated event
and the mailer can send another email. The queue has a DLQ after three attempts.

The builder shares the API's image and security group so the existing Aurora
ingress rule applies. It reaches S3 through a gateway endpoint in its subnet
route tables. The mailer has no VPC attachment or DB access. Its IAM permission
is limited to reading `reports/*` and sending from the configured SES identity.

## Prerequisites for a deployment

1. A working `infra/backend.yml` stack in us-east-1 with its image in ECR,
   VPC/subnets/route tables, security group and Aurora database. Migrations
   and meeting data must already exist.
2. The database secret ARN from the backend stack's `DatabaseSecretArn` output.
   The backend stack generates the password in Secrets Manager. Both functions
   use a CloudFormation dynamic reference to resolve it when deployed; do not
   place the credential in Git or a plain CloudFormation parameter.
3. A private S3 artifact bucket containing a zip file with
   `backend/app/reports/mailer_handler.py` at the zip root. Do not use the
   website's CloudFront origin bucket unless its distribution and policy block
   public access to the code artifact.
4. A sender identity and a recipient address verified in SES in the deployment
   region while the account remains in the SES sandbox. Supplying `SenderDomain`
   to the stack creates a domain identity and outputs three DKIM CNAME pairs.
   Publish them in the domain's DNS before expecting mail to send. Without an
   owned domain, pre-verify the sender **email** identity in SES before the
   stack is deployed. That is an alternative to the exact domain step in the
   assignment and should be agreed with the lecturer.

`ReportFromEmail`, `ReportToEmail` and `SenderDomain` are deployment parameters,
not constants in the report code. The CloudFormation stack is tagged through
`ProjectName` where the service supports tags. Reports expire after 90 days;
the bucket itself is retained on stack deletion to avoid silent data loss.

## Verification and evidence

1. Test the CSV generator against the local Compose PostgreSQL database before
   deployment. Use two distinct weeks so the object listing has two keys.
2. First deploy with `ScheduleTarget=LAMBDA` and
   `ScheduleExpression=rate(5 minutes)` to capture a genuine direct schedule
   log. Then update the stack with `ScheduleTarget=SQS`, keep the temporary
   rate until an SQS-driven schedule has run, and restore the Monday cron.
3. Run `make report-now WEEK=<another-week>`. Expect builder logs with
   `trigger=sqs source=report-now`, a mailer log with `trigger=s3`, and a
   delivered CSV attachment. The scheduled SQS invocation has
   `trigger=sqs source=schedule`; the first direct stage produces
   `trigger=schedule source=schedule`.
4. Run `make report-objects` for the S3 listing to submit. Capture the email
   screenshot in the real recipient inbox.
5. Send a deliberately failing week, observe three receives and the DLQ,
   remove the failure and redrive the message. Do not leave a failure injection
   enabled in the deployed code.

## Written answers required in Part 3, Step 7

- Email sending is not idempotent. Store a sent marker keyed by the report week
  plus recipient (or immutable report version plus recipient) in a durable
  conditional-write store before sending, with a strategy for the crash window
  between marking and sending.
- The VPC builder cannot reach SES without a network path. NAT, an SES
  interface endpoint (for supported SES APIs), or this separate outside-VPC
  mailer are the proposed options. Compare the current regional prices before
  quoting monthly numbers in the submission.
- A week-long download link cannot depend on a short-lived Lambda role
  credential. Use a long-lived signing mechanism such as CloudFront signed URLs
  backed by the private S3 object, with a seven-day policy.
