# ADR 0009. Run the SuccessfulSuccess core on Google Cloud

Status: Accepted for Lab 9. The AWS stack remains the existing application while the GCP deployment is verified.

## Context

The project currently uses CloudFront/S3, ECS on Fargate and Supabase PostgreSQL for the core. Lab 4's Lambda and Aurora architecture is the course reference. This lab deploys a separate copy of the core, using the existing PostgreSQL migrations. It starts with an empty database and uses synthetic meetings for the demonstration.

## Decision

| AWS or course reference | Google Cloud counterpart | Decision for SuccessfulSuccess |
| --- | --- | --- |
| S3, CloudFront and WAF | Firebase Hosting | Replace for the GCP frontend. Use managed HTTPS on the Firebase site and keep the existing AWS site available. |
| ECS/Fargate and ALB, or Lambda Function URL in the reference | Cloud Run | Replace for the GCP API. Use the existing HTTP container, request billing and zero minimum instances. |
| ECR | Artifact Registry | Replace for the GCP image. Deploy a pinned image digest. |
| Supabase PostgreSQL, or Aurora in the reference | Cloud SQL PostgreSQL | Replace for the GCP copy. Use single-zone Enterprise db-f1-micro with 10 GB SSD. |
| DynamoDB, if used | Firestore | Drop from this deployment. The meetings model uses SQL relations and migrations. |
| Cognito with Google | Identity Platform or Firebase Authentication | Keep Cognito. Register the Firebase callback and logout destinations and verify Cognito tokens in FastAPI. |
| EventBridge Scheduler | Cloud Scheduler | Keep the existing weekly-report schedule on AWS. |
| SQS | Pub/Sub or Cloud Tasks | Keep the report queue and its consumers on AWS. |
| S3 event to Lambda | Cloud Storage, Eventarc and Cloud Run | Keep the report bucket and mailer trigger on AWS. |
| SES | External email provider | Keep SES and its existing scoped IAM role. The GCP core needs no mail API key. If a future provider requires one, store it in Secret Manager and grant its workload access to that secret alone. |
| Bedrock | Vertex AI | Keep the existing agenda parser on AWS. Model access, cost and behavior can be evaluated separately from the migration. |
| SSM or Secrets Manager | Secret Manager | Replace for the GCP database connection string. Keep AWS secrets on AWS. |
| CloudWatch Logs | Cloud Logging | Replace for GCP workloads. Keep AWS logs on AWS. |
| IAM roles | Service accounts and IAM | Use a dedicated Terraform deployer and a Cloud Run runtime identity with no keys. Keep AWS IAM separate. |
| Terraform AWS provider | Terraform Google provider | Use a separate HCP Terraform workspace and state for GCP. |

## Database trade-offs

Cloud SQL keeps the existing relational queries and migrations. Co-locating the API and database in us-central1 avoids an inter-cloud database round trip. It charges for compute while running even with no users. Stopping it outside demo hours saves compute but breaks DB-backed requests during those hours and retains storage charges. Firestore would remove the idle database instance and can be cheaper within its quotas, at the cost of rewriting repositories, relations and access patterns. Keeping Supabase as the GCP API's database would save a migration, but introduce a cross-provider dependency, possible network charges and variable latency. Cloud SQL stays running during the agreed assessment window.

The weekly report continues to cover meetings in the original AWS-side application database. The agenda parser remains hosted on AWS, and the GCP core can run without calling it. Each copy has its own meeting data.
