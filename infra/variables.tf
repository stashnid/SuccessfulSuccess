variable "aws_region" {
  type        = string
  description = "Region of the three existing CloudFormation stacks."
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Existing resource-name prefix; changing it may replace resources."
  default     = "successfulsuccess"
}

variable "app_urls" {
  type        = list(string)
  description = "Existing Cognito logout URLs, including trailing slashes."
}

variable "callback_urls" {
  type        = list(string)
  description = "Existing Cognito callback URLs, including trailing slashes."
}

variable "google_client_id" {
  type        = string
  description = "Google OAuth web client ID."
}

variable "google_client_secret" {
  type        = string
  description = "Google OAuth client secret; set only as a sensitive HCP Terraform variable."
  sensitive   = true
}

variable "report_builder_image_uri" {
  type        = string
  description = "Existing report-builder Lambda image URI pinned to its own digest."
}

variable "parser_image_uri" {
  type        = string
  description = "Existing agenda-parser Lambda image URI pinned to its own digest."
}

variable "database_secret_arn" {
  type        = string
  description = "ARN of the existing Secrets Manager secret for the database URL."
}

variable "mailer_code_bucket" {
  type        = string
  description = "Existing private bucket containing the mailer deployment ZIP."
}

variable "mailer_code_key" {
  type        = string
  description = "Immutable S3 key for the mailer ZIP."
}

variable "report_from_email" {
  type        = string
  description = "SES-verified sender address."
}

variable "report_to_email" {
  type        = string
  description = "Verified recipient while SES is sandboxed."
}

variable "sender_domain" {
  type        = string
  description = "Optional SES sending domain; empty in the current email-only setup."
  default     = ""
}

variable "schedule_expression" {
  type        = string
  description = "Actual weekly schedule expression; confirm from the live stack before import."
  default     = "cron(0 7 ? * MON *)"
}

variable "schedule_target" {
  type        = string
  description = "SQS for the normal flow, or LAMBDA for the direct-trigger exercise."
  default     = "SQS"

  validation {
    condition     = contains(["SQS", "LAMBDA"], var.schedule_target)
    error_message = "schedule_target must be SQS or LAMBDA."
  }
}

variable "cognito_user_pool_id" {
  type        = string
  description = "Existing Cognito user pool ID passed to the agenda parser."
}

variable "cognito_client_id" {
  type        = string
  description = "Existing Cognito web client ID passed to the agenda parser."
}

variable "site_origin" {
  type        = string
  description = "Exact HTTPS CloudFront origin allowed by the parser CORS policy."
}

variable "budget_email" {
  type        = string
  description = "Email address for the existing monthly AWS Budget alert."
}

variable "parser_model" {
  type        = string
  description = "Existing Bedrock model ID used by the agenda parser."
  default     = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "parser_role_name" {
  type        = string
  description = "Actual IAM role physical name from the successfulsuccess-ai stack."
}

variable "parser_url_statement_id" {
  type        = string
  description = "Actual Lambda URL permission statement ID from the live policy."
}

variable "parser_invoke_statement_id" {
  type        = string
  description = "Actual Lambda invoke permission statement ID from the live policy."
}

variable "builder_role_name" {
  type        = string
  description = "Existing report builder IAM role physical name."
}

variable "mailer_role_name" {
  type        = string
  description = "Existing report mailer IAM role physical name."
}

variable "scheduler_role_name" {
  type        = string
  description = "Existing weekly scheduler IAM role physical name."
}

variable "report_alarm_name" {
  type        = string
  description = "Existing report dead-letter alarm physical name."
}

variable "mailer_permission_statement_id" {
  type        = string
  description = "Actual S3-to-mailer Lambda permission statement ID."
}

variable "reports_notification_id" {
  type        = string
  description = "Existing S3 Lambda notification configuration ID."
}
