locals {
  name             = "successfulsuccess"
  frontend_url     = "https://${var.project_id}.web.app"
  socket_directory = "/cloudsql"
  runtime_email    = "spry-api@${var.project_id}.iam.gserviceaccount.com"
  database_env = {
    COGNITO_CLIENT_ID       = var.cognito_client_id
    COGNITO_USER_POOL_ID    = var.cognito_user_pool_id
    COGNITO_REGION          = split("_", var.cognito_user_pool_id)[0]
    CORS_ORIGINS            = local.frontend_url
    RUN_MIGRATIONS_ON_START = "false"
  }
}

resource "google_project_service" "lab" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "sqladmin.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "api" {
  location      = var.region
  repository_id = local.name
  format        = "DOCKER"

  depends_on = [google_project_service.lab["artifactregistry.googleapis.com"]]
}

resource "google_sql_database_instance" "postgres" {
  name                = "spry-pg"
  region              = var.region
  database_version    = "POSTGRES_16"
  deletion_protection = false

  settings {
    edition           = "ENTERPRISE"
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    disk_size         = 10
    disk_type         = "PD_SSD"
    disk_autoresize   = false
    activation_policy = var.database_running ? "ALWAYS" : "NEVER"

    ip_configuration {
      ipv4_enabled = true
    }
  }

  depends_on = [google_project_service.lab["sqladmin.googleapis.com"]]
}

resource "google_sql_database" "meetings" {
  name     = "meetings"
  instance = google_sql_database_instance.postgres.name
}

resource "random_password" "database" {
  length  = 32
  special = false
}

resource "google_sql_user" "app" {
  name     = "spry_app"
  instance = google_sql_database_instance.postgres.name
  password = random_password.database.result
}

resource "google_secret_manager_secret" "database_url" {
  secret_id = "spry-database-url"

  replication {
    auto {}
  }

  depends_on = [google_project_service.lab["secretmanager.googleapis.com"]]
}

resource "google_secret_manager_secret_version" "database_url" {
  secret      = google_secret_manager_secret.database_url.id
  secret_data = "postgresql+asyncpg://${google_sql_user.app.name}:${random_password.database.result}@/${google_sql_database.meetings.name}?host=${local.socket_directory}/${google_sql_database_instance.postgres.connection_name}"
}

resource "google_secret_manager_secret_iam_member" "runtime" {
  secret_id = google_secret_manager_secret.database_url.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.runtime_email}"
}
