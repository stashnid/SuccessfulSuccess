# ADR 0007: Terraform for the course infrastructure

Status: proposed until the three existing stacks are safely imported and an HCP Terraform run succeeds.

## Context

Labs 4–6 created the Cognito sign-in, weekly report pipeline and agenda parser with three CloudFormation templates. The application also uses Google OAuth and GitHub. The course now asks for a shared, reviewable infrastructure workflow and a central state that a second environment can use later. The deployed Cognito users and reports in S3 must survive the migration.

## Decision

Describe these three stacks in one Terraform root module under `infra/`, with one HCP Terraform workspace for the current environment. Keep the other CloudFormation templates outside this migration. Import the existing resources into HCP state after CloudFormation has retained and released them; do not create replacement Cognito, S3, queue or Lambda resources. A reviewed GitHub push or merge starts the HCP plan and apply. The Makefile may run `terraform fmt`, `validate` and `plan`, but not `apply` for this workspace.

The HCP workspace assumes a narrowly scoped AWS role through OIDC for each run. AWS access keys do not go into HCP variables or Git. The Google OAuth client secret is a sensitive workspace variable. HCP state still contains sensitive values, so workspace and state-version access must be limited to the project operator; the `sensitive` flag only redacts plan output. Local `.tfstate`, plans, credentials and secret variable files are ignored by Git.

## Alternatives

- Keep CloudFormation: avoids migration risk and AWS retains the state, but does not give the course's single Terraform workflow across AWS, Google and GitHub.
- Use AWS CDK: fits AWS well, but adds a programming-language synthesis step and still uses CloudFormation state.
- Use OpenTofu: supports a similar HCL workflow, but this lab specifically asks for an HCP Terraform run and its screenshot.

## Consequences

Terraform plans make proposed changes visible before the HCP run applies them, and a locked central state prevents concurrent applies. The migration itself is risky: the current stack resources must all receive Retain policies before stack deletion, every import ID must be checked, and the first plan must show imports without replacement or destruction. The user pool and reports bucket have `prevent_destroy` as an additional guard. A change requiring both application code and infrastructure is applied in HCP first when the application needs the new resource or setting; the application deployment follows after the infrastructure is ready.

HCP Terraform is now an operational dependency. If it is unavailable, the team can still read the code and AWS resources, but normal infrastructure changes wait. For an urgent incident, an operator may make the smallest necessary AWS change, record it in Git and reconcile drift after HCP recovers. A separate local state must not be created for the production resources.
