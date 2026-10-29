# SuccessfulSuccess — Meetings

A full-stack web application for viewing today's meetings and managing their details and participants, with sign-in through Amazon Cognito.

**Stack:** Next.js · TypeScript · shadcn/ui · FastAPI · SQLAlchemy · PostgreSQL · Docker

> This repository is a fork of [dobosevych/SuccessfulSuccess](https://github.com/dobosevych/SuccessfulSuccess), used for coursework and further development. Setup and validation notes are linked below.

[![Style](https://github.com/stashnid/SuccessfulSuccess/actions/workflows/style.yml/badge.svg)](https://github.com/stashnid/SuccessfulSuccess/actions/workflows/style.yml)

## Features

- View meetings for a selected day, including their descriptions and participants.
- Create, update, and delete meetings through the web interface and API.
- Authenticate with Cognito Managed Login using email/password or a configured Google provider.
- Keep meeting data scoped to the signed-in user.
- Explore the backend schema through Swagger UI.

## Run locally

**Requirements:** Git, Docker with Docker Compose, and a configured AWS Cognito user pool for sign-in.

```bash
git clone https://github.com/stashnid/SuccessfulSuccess.git
cd SuccessfulSuccess
cp .env.example .env
```

Set the actual `COGNITO_USER_POOL_ID`, `COGNITO_CLIENT_ID`, and `COGNITO_DOMAIN` values in `.env` before starting. Register `http://localhost:3000/auth/callback/` as a callback URL and `http://localhost:3000/` as a logout URL in Cognito. See the [authentication setup guide](docs/lab3-setup.md) for details.

```bash
docker compose up --build
```

- Application: [localhost:3000](http://localhost:3000)
- API documentation: [localhost:8000/docs](http://localhost:8000/docs)
- Health check: [localhost:8000/health](http://localhost:8000/health)

The backend applies migrations on startup by default. Sign-in requires internet access to Cognito even when the application runs locally. Host ports can be changed in `.env`; update the API URL, CORS origins, and Cognito redirect URLs to match.

## Repository guide

- [frontend/](frontend/) — Next.js interface, authentication flow, and UI components.
- [backend/](backend/) — FastAPI routes, services, database models, migrations, and tests.
- [infra/](infra/) — Terraform configuration for Cognito, weekly reports and agenda parsing; other AWS infrastructure remains in CloudFormation.
- [scripts/](scripts/) — deployment and configuration helpers.
- [SPEC.md](SPEC.md) — application specification.
- [docker-compose.yml](docker-compose.yml) — local frontend, backend, and PostgreSQL stack.

## Coursework and deployment notes

- [Authentication setup](docs/lab3-setup.md) — Cognito configuration, local setup, and recorded validation status.
- [Lab 3 notes](docs/lab3-notes.md) — implementation and validation notes.
- [CloudFront API integration](docs/lab3-stretch.md) — same-origin API routing and backend authentication.
- [Lab 3 plan](LAB3_PLAN.md) — coursework checklist.

The current [Makefile](Makefile) provides `deploy-frontend`, `deploy-backend`, `connect-api`, and `configure-backend-auth`. These target an existing AWS environment and require its credentials and configuration; they are not needed to start Docker Compose locally. See the setup notes for infrastructure limitations and remaining checks.

### Lab 7 infrastructure migration

The three course stacks for authentication, weekly reports and agenda parsing are described in [infra/](infra/) as one Terraform root module. The target HCP Terraform organization is `successfulsuccess-stashnid`, with workspace `successfulsuccess-dev` and working directory `infra/`. Its state is remote and its AWS access uses short-lived OIDC credentials. The Google OAuth client secret belongs in a **sensitive workspace variable** named `google_client_secret`; do not put it in Git or `terraform.tfvars`.

Run `make infra-fmt`, `make infra-validate` and `make infra-plan` to review configuration. The Makefile has no infrastructure apply target. Application deployment is separate: the manual GitHub Actions workflow deploys the ECS backend and CloudFront site after the infrastructure is ready. Its public Cognito and parser values are repository variables; local deployment scripts can also read them from Terraform outputs.

Existing resources must be retained by CloudFormation, imported into the HCP state, and verified by a no-change plan before removing the old stack templates. The migration status and safety gates are recorded in [Lab 7 inventory](docs/lab7-migration-inventory.md); the architecture decision is in [ADR 0007](docs/adr/0007-terraform.md).

## Validation

Backend tests are in [backend/tests/](backend/tests/) and use PostgreSQL. Style checks are configured in [.github/workflows/style.yml](.github/workflows/style.yml). See the workflow and backend configuration for the exact tools and versions.

## Time handling

Meeting timestamps are stored in UTC. The application timezone defaults to `Europe/Kyiv`; meetings that overlap a calendar day are included in that day's results.
