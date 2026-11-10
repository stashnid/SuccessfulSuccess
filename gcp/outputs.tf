output "registry" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.api.repository_id}"
}

output "api_url" {
  value = try(google_cloud_run_v2_service.api[0].uri, null)
}

output "frontend_url" {
  value = local.frontend_url
}

output "cognito" {
  value = {
    user_pool_id = var.cognito_user_pool_id
    client_id    = var.cognito_client_id
    domain       = var.cognito_domain
  }
}
