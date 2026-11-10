# Lab 9 Google Cloud deployment

Use a dedicated, billing-enabled Google Cloud project. Set a project-filtered budget alert at $5 with thresholds of 50%, 90% and 100% before creating billable resources. The budget sends alerts. This setup uses the existing Cognito pool, an empty Google Cloud PostgreSQL database and a separate HCP Terraform workspace. The existing AWS application, weekly report and agenda parser continue to run on AWS.

## Bootstrap identity

1. Create a CLI-driven workspace named `successfulsuccess-gcp` in the existing HCP Terraform organization. Leave its working directory unset for CLI runs from `gcp/`. Use a supported Terraform version (1.10 or later). Record its immutable workspace ID and organization ID.
2. Run `gcloud auth application-default login` and `gcloud auth application-default set-quota-project "$PROJECT_ID"` as the project administrator. Use a separate local working directory or access-controlled state storage for the bootstrap state.
3. Run these commands from the repository root. Review the plan before applying it.

```sh
export TF_VAR_project_id="$PROJECT_ID"
export TF_VAR_hcp_organization_id="<org-ID>"
export TF_VAR_hcp_workspace_id="<ws-ID>"
terraform -chdir=gcp/bootstrap init
terraform -chdir=gcp/bootstrap plan
terraform -chdir=gcp/bootstrap apply
terraform -chdir=gcp/bootstrap output -json hcp_environment
```

4. Set the four output values as environment variables in the GCP HCP workspace. Add Terraform variables `project_id`, `cognito_user_pool_id`, `cognito_client_id`, and `cognito_domain`. The Cognito app client must permit `https://PROJECT_ID.web.app/auth/callback/` and logout to `https://PROJECT_ID.web.app/`. Preserve the existing AWS site URLs if using the same client. The frontend and API must use the same client ID. Google OAuth still returns to Cognito as before.

The Workload Identity provider admits only tokens from this HCP organization and workspace by their IDs. The API identity can connect to Cloud SQL and read the one database secret. Terraform generates the PostgreSQL password and stores the connection string in Secret Manager. The restricted GCP HCP state also contains the generated value, so keep state and plans private.

## Build and deploy

Start with `api_image` unset. The first plan creates Artifact Registry, Cloud SQL and the database credentials. Inspect and apply it using the GCP workspace, never the AWS workspace.

```sh
terraform -chdir=gcp init
terraform -chdir=gcp plan
terraform -chdir=gcp apply
REGISTRY="$(terraform -chdir=gcp output -raw registry)"
IMAGE="$REGISTRY/api:$(git rev-parse --short HEAD)"
gcloud auth login
gcloud auth configure-docker "${REGISTRY%%/*}"
docker buildx build --platform linux/amd64 --push -t "$IMAGE" backend
gcloud artifacts docker images describe "$IMAGE" --project "$PROJECT_ID" \
  --format='value(image_summary.fully_qualified_digest)'
```

Set the printed digest URI as the HCP Terraform variable `api_image`. Plan and apply again to create the Cloud Run API and migration job. Use the existing HTTP Dockerfile. Cloud Run supplies `PORT=8000` to match the container, and FastAPI validates Cognito tokens on user-data endpoints. Run Alembic once against the empty Cloud SQL database before sending traffic.

```sh
gcloud run jobs execute spry-migrate --region us-central1 --project "$PROJECT_ID" --wait
API_URL="$(terraform -chdir=gcp output -raw api_url)"
curl --fail --silent "$API_URL/health"
```

Add Firebase to the dedicated project and create its default Hosting site if it does not exist. Use the project ID as the site ID to match the frontend URL in Terraform. Deploy the static export from the repository root.

```sh
firebase login
firebase projects:addfirebase "$PROJECT_ID"
firebase hosting:sites:list --project "$PROJECT_ID"
# Only if the default site does not exist:
firebase hosting:sites:create "$PROJECT_ID" --project "$PROJECT_ID"

npm --prefix frontend ci
NEXT_OUTPUT=export NEXT_TELEMETRY_DISABLED=1 \
  NEXT_PUBLIC_API_BASE_URL="$API_URL" \
  NEXT_PUBLIC_COGNITO_USER_POOL_ID="$COGNITO_USER_POOL_ID" \
  NEXT_PUBLIC_COGNITO_CLIENT_ID="$COGNITO_CLIENT_ID" \
  NEXT_PUBLIC_COGNITO_DOMAIN="$COGNITO_DOMAIN" \
  NEXT_PUBLIC_PARSER_URL='' \
  npm --prefix frontend run build -- --webpack
firebase deploy --only hosting --project "$PROJECT_ID"
```

In a private window, open the `.web.app` URL, sign in, create a synthetic meeting and reload Today. Verify that `GET /api/v1/meetings` returns HTTP 200 and the meeting from Cloud SQL. Also confirm the same API returns 401 without a token. The public health check verifies connectivity, while the meetings read verifies the actual feature.

## Stop after grading

Keep the submitted URL and database working through the agreed grading window. To stop the instance, set the HCP variable `database_running=false`, review the plan and apply it. The API will be unable to read meetings while the database is stopped. Disk storage and retained idle IPv4 can still be billed. To end those charges after grading, review and apply a destroy plan for the GCP workspace; then disable Firebase Hosting, clean up demo data, and destroy the separate bootstrap stack if it is no longer needed. Verify the remaining resources and check Billing Reports the next day.
