variable "project_id" {
  type        = string
  description = "Dedicated, billing-enabled Google Cloud project for Lab 9."
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "api_image" {
  type        = string
  default     = null
  description = "Immutable Artifact Registry image URI with digest. Leave unset for the first apply."

  validation {
    condition     = var.api_image == null || can(regex("@sha256:[a-f0-9]{64}$", var.api_image))
    error_message = "Use an Artifact Registry image pinned to a SHA-256 digest."
  }
}

variable "cognito_user_pool_id" {
  type        = string
  description = "Existing AWS Cognito user pool ID."
}

variable "cognito_client_id" {
  type        = string
  description = "Cognito public client that allows the Firebase Hosting callback."
}

variable "cognito_domain" {
  type        = string
  description = "Existing Cognito hosted sign-in domain without https://."
}

variable "database_running" {
  type        = bool
  default     = true
  description = "Set false after grading to stop Cloud SQL compute. Storage and idle IPv4 can still incur charges."
}
