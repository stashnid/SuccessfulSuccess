output "user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.web.id
}

output "cognito_hosted_domain" {
  value = "${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "google_redirect_uri" {
  value = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com/oauth2/idpresponse"
}

output "parser_url" {
  value = aws_lambda_function_url.parser.function_url
}

output "parser_log_group" {
  value = aws_cloudwatch_log_group.parser.name
}

output "budget_name" {
  value = aws_budgets_budget.monthly.name
}

output "reports_bucket_name" {
  value = aws_s3_bucket.reports.bucket
}

output "report_queue_url" {
  value = aws_sqs_queue.report_requests.url
}

output "report_queue_arn" {
  value = aws_sqs_queue.report_requests.arn
}

output "dead_letter_queue_url" {
  value = aws_sqs_queue.report_dlq.url
}

output "builder_function_name" {
  value = aws_lambda_function.builder.function_name
}

output "dead_letter_alert_topic_arn" {
  value = aws_sns_topic.report_dlq.arn
}
