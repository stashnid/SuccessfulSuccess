resource "google_cloud_run_v2_service" "api" {
  count = var.api_image == null ? 0 : 1

  name                 = local.name
  location             = var.region
  ingress              = "INGRESS_TRAFFIC_ALL"
  invoker_iam_disabled = true
  deletion_protection  = false

  template {
    service_account = local.runtime_email

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    containers {
      image = var.api_image

      ports {
        container_port = 8000
      }

      resources {
        cpu_idle = true
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      dynamic "env" {
        for_each = local.database_env
        content {
          name  = env.key
          value = env.value
        }
      }

      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.database_url.secret_id
            version = google_secret_manager_secret_version.database_url.version
          }
        }
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = local.socket_directory
      }
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.postgres.connection_name]
      }
    }
  }

  depends_on = [
    google_project_service.lab["run.googleapis.com"],
    google_secret_manager_secret_iam_member.runtime,
  ]
}

resource "google_cloud_run_v2_job" "migrate" {
  count = var.api_image == null ? 0 : 1

  name                = "spry-migrate"
  location            = var.region
  deletion_protection = false

  template {
    template {
      service_account = local.runtime_email
      max_retries     = 0
      timeout         = "300s"

      containers {
        image   = var.api_image
        command = ["alembic"]
        args    = ["upgrade", "head"]

        env {
          name = "DATABASE_URL"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.database_url.secret_id
              version = google_secret_manager_secret_version.database_url.version
            }
          }
        }

        volume_mounts {
          name       = "cloudsql"
          mount_path = local.socket_directory
        }
      }

      volumes {
        name = "cloudsql"
        cloud_sql_instance {
          instances = [google_sql_database_instance.postgres.connection_name]
        }
      }
    }
  }

  depends_on = [
    google_project_service.lab["run.googleapis.com"],
    google_secret_manager_secret_iam_member.runtime,
  ]
}
