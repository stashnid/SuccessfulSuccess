terraform {
  required_version = ">= 1.10.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.21"
    }
  }
}

variable "project_id" {
  type = string
}

variable "hcp_organization_id" {
  type = string
}

variable "hcp_workspace_id" {
  type = string
}

provider "google" {
  project = var.project_id
}

resource "google_project_service" "identity" {
  for_each = toset(["iam.googleapis.com", "iamcredentials.googleapis.com", "sts.googleapis.com"])

  service            = each.value
  disable_on_destroy = false
}

resource "google_service_account" "terraform" {
  account_id   = "spry-terraform"
  display_name = "Lab 9 Terraform deployer"

  depends_on = [google_project_service.identity["iam.googleapis.com"]]
}

resource "google_service_account" "api" {
  account_id   = "spry-api"
  display_name = "Lab 9 Cloud Run runtime"

  depends_on = [google_project_service.identity["iam.googleapis.com"]]
}

resource "google_project_iam_member" "terraform" {
  for_each = toset([
    "roles/artifactregistry.admin",
    "roles/cloudsql.admin",
    "roles/run.admin",
    "roles/secretmanager.admin",
    "roles/serviceusage.serviceUsageAdmin",
  ])

  project = var.project_id
  role    = each.value
  member  = google_service_account.terraform.member
}

resource "google_project_iam_member" "sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = google_service_account.api.member
}

resource "google_service_account_iam_member" "act_as_runtime" {
  service_account_id = google_service_account.api.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.terraform.member
}

resource "google_iam_workload_identity_pool" "hcp" {
  workload_identity_pool_id = "spry-hcp-terraform"
  display_name              = "Spry HCP Terraform"

  depends_on = [google_project_service.identity]
}

resource "google_iam_workload_identity_pool_provider" "hcp" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.hcp.workload_identity_pool_id
  workload_identity_pool_provider_id = "hcp-terraform"

  attribute_mapping = {
    "google.subject"                   = "assertion.sub"
    "attribute.terraform_workspace_id" = "assertion.terraform_workspace_id"
  }
  attribute_condition = "assertion.terraform_organization_id == ${jsonencode(var.hcp_organization_id)} && assertion.terraform_workspace_id == ${jsonencode(var.hcp_workspace_id)}"

  oidc {
    issuer_uri        = "https://app.terraform.io"
    allowed_audiences = ["gcp.workload.identity"]
  }
}

resource "google_service_account_iam_member" "federated_workspace" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.hcp.name}/attribute.terraform_workspace_id/${var.hcp_workspace_id}"
}

output "hcp_environment" {
  value = {
    TFC_GCP_PROVIDER_AUTH              = "true"
    TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL  = google_service_account.terraform.email
    TFC_GCP_WORKLOAD_PROVIDER_NAME     = google_iam_workload_identity_pool_provider.hcp.name
    TFC_GCP_WORKLOAD_IDENTITY_AUDIENCE = "gcp.workload.identity"
  }
}
