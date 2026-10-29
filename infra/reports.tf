# Existing Lab 5 report infrastructure. All stateful and identity-bearing
# resources are protected until their import and no-change plan are verified.
locals {
  reports_bucket_name = "${var.project_name}-reports-${data.aws_caller_identity.current.account_id}"
  reports_bucket_arn  = "arn:aws:s3:::${local.reports_bucket_name}"
  ses_identity_arn    = "arn:aws:ses:${var.aws_region}:${data.aws_caller_identity.current.account_id}:identity/${var.sender_domain == "" ? var.report_from_email : var.sender_domain}"
}

resource "aws_s3_bucket" "reports" {
  bucket        = local.reports_bucket_name
  force_destroy = false
  tags          = { PROJECT_NAME = var.project_name }
  lifecycle { prevent_destroy = true }
}

resource "aws_s3_bucket_public_access_block" "reports" {
  bucket                  = aws_s3_bucket.reports.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "reports" {
  bucket = aws_s3_bucket.reports.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id
  rule {
    id     = "DeleteOldReports"
    status = "Enabled"
    filter { prefix = "reports/" }
    expiration { days = 90 }
    noncurrent_version_expiration { noncurrent_days = 90 }
  }
}

resource "aws_s3_bucket_policy" "reports" {
  bucket = aws_s3_bucket.reports.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "RequireTLS"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [local.reports_bucket_arn, "${local.reports_bucket_arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

resource "aws_sqs_queue" "report_dlq" {
  name                      = "${var.project_name}-report-requests-dlq"
  max_message_size          = 1048576
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
  tags                      = { PROJECT_NAME = var.project_name }
  lifecycle { prevent_destroy = true }
}

resource "aws_sqs_queue" "report_requests" {
  name                       = "${var.project_name}-report-requests"
  max_message_size           = 1048576
  visibility_timeout_seconds = 360
  sqs_managed_sse_enabled    = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.report_dlq.arn
    maxReceiveCount     = 3
  })
  tags = { PROJECT_NAME = var.project_name }
  lifecycle { prevent_destroy = true }
}

resource "aws_iam_role" "builder" {
  name = var.builder_role_name
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = { PROJECT_NAME = var.project_name }
  lifecycle { prevent_destroy = true }
}

resource "aws_iam_role_policy_attachment" "builder_basic" {
  role       = aws_iam_role.builder.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "builder" {
  name = "ReadQueueWriteReports"
  role = aws_iam_role.builder.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"], Resource = aws_sqs_queue.report_requests.arn },
      { Effect = "Allow", Action = "secretsmanager:GetSecretValue", Resource = var.database_secret_arn },
      { Effect = "Allow", Action = "s3:PutObject", Resource = "${local.reports_bucket_arn}/reports/*" }
    ]
  })
}

resource "aws_cloudwatch_log_group" "builder" {
  name              = "/aws/lambda/${var.project_name}-report-builder"
  retention_in_days = 7
  tags              = { PROJECT_NAME = var.project_name }
  lifecycle { prevent_destroy = true }
}

resource "aws_lambda_function" "builder" {
  function_name = "${var.project_name}-report-builder"
  package_type  = "Image"
  image_uri     = var.report_builder_image_uri
  architectures = ["arm64"]
  role          = aws_iam_role.builder.arn
  memory_size   = 1024
  timeout       = 60

  image_config { command = ["app.reports.lambda_handler.handler"] }
  logging_config {
    log_group  = aws_cloudwatch_log_group.builder.name
    log_format = "Text"
  }
  environment {
    variables = {
      DATABASE_SECRET_ARN = var.database_secret_arn
      APP_TIMEZONE        = "Europe/Kyiv"
      REPORTS_BUCKET      = local.reports_bucket_name
    }
  }
  tags = { PROJECT_NAME = var.project_name }
  lifecycle { prevent_destroy = true }
}

resource "aws_lambda_event_source_mapping" "report_queue" {
  event_source_arn = aws_sqs_queue.report_requests.arn
  function_name    = aws_lambda_function.builder.function_name
  batch_size       = 1
  enabled          = true
}

resource "aws_iam_role" "scheduler" {
  name = var.scheduler_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
    }]
  })
  tags = { PROJECT_NAME = var.project_name }
  lifecycle { prevent_destroy = true }
}

resource "aws_iam_role_policy" "scheduler" {
  name = "EnqueueWeeklyReport"
  role = aws_iam_role.scheduler.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = "sqs:SendMessage", Resource = aws_sqs_queue.report_requests.arn },
      { Effect = "Allow", Action = "lambda:InvokeFunction", Resource = aws_lambda_function.builder.arn }
    ]
  })
}

resource "aws_scheduler_schedule" "weekly_report" {
  name                         = "${var.project_name}-weekly-report"
  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = "Europe/Kyiv"
  state                        = "ENABLED"
  flexible_time_window { mode = "OFF" }
  target {
    arn      = var.schedule_target == "LAMBDA" ? aws_lambda_function.builder.arn : aws_sqs_queue.report_requests.arn
    role_arn = aws_iam_role.scheduler.arn
    input    = "{\"week\":null,\"source\":\"schedule\"}"
  }
  lifecycle { prevent_destroy = true }
}

resource "aws_iam_role" "mailer" {
  name = var.mailer_role_name
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = { PROJECT_NAME = var.project_name }
  lifecycle { prevent_destroy = true }
}

resource "aws_iam_role_policy_attachment" "mailer_basic" {
  role       = aws_iam_role.mailer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "mailer" {
  name = "ReadReportSendEmail"
  role = aws_iam_role.mailer.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = "s3:GetObject", Resource = "${local.reports_bucket_arn}/reports/*" },
      { Effect = "Allow", Action = ["ses:SendEmail", "ses:SendRawEmail"], Resource = local.ses_identity_arn }
    ]
  })
}

resource "aws_cloudwatch_log_group" "mailer" {
  name              = "/aws/lambda/${var.project_name}-report-mailer"
  retention_in_days = 7
  tags              = { PROJECT_NAME = var.project_name }
  lifecycle { prevent_destroy = true }
}

resource "aws_lambda_function" "mailer" {
  function_name = "${var.project_name}-report-mailer"
  role          = aws_iam_role.mailer.arn
  runtime       = "python3.12"
  handler       = "mailer_handler.handler"
  s3_bucket     = var.mailer_code_bucket
  s3_key        = var.mailer_code_key
  memory_size   = 128
  timeout       = 30
  logging_config {
    log_group  = aws_cloudwatch_log_group.mailer.name
    log_format = "Text"
  }
  environment {
    variables = {
      REPORT_FROM_EMAIL = var.report_from_email
      REPORT_TO_EMAILS  = var.report_to_email
    }
  }
  tags = { PROJECT_NAME = var.project_name }
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [s3_bucket, s3_key, publish]
  }
}

resource "aws_lambda_permission" "mailer_s3" {
  statement_id   = var.mailer_permission_statement_id
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.mailer.function_name
  principal      = "s3.amazonaws.com"
  source_arn     = local.reports_bucket_arn
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket_notification" "reports" {
  bucket = aws_s3_bucket.reports.id
  lambda_function {
    id                  = var.reports_notification_id
    lambda_function_arn = aws_lambda_function.mailer.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "reports/"
    filter_suffix       = ".csv"
  }
  depends_on = [aws_lambda_permission.mailer_s3]
}

resource "aws_sns_topic" "report_dlq" {
  name = "${var.project_name}-report-dlq-alerts"
  tags = { PROJECT_NAME = var.project_name }
  lifecycle { prevent_destroy = true }
}

resource "aws_sns_topic_policy" "report_dlq" {
  arn = aws_sns_topic.report_dlq.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowAccountManagement"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = ["sns:GetTopicAttributes", "sns:SetTopicAttributes", "sns:AddPermission", "sns:RemovePermission", "sns:DeleteTopic", "sns:Subscribe", "sns:ListSubscriptionsByTopic", "sns:Publish"]
        Resource  = aws_sns_topic.report_dlq.arn
      },
      {
        Sid       = "AllowReportAlarm"
        Effect    = "Allow"
        Principal = { Service = "cloudwatch.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.report_dlq.arn
        Condition = {
          ArnLike      = { "aws:SourceArn" = "arn:aws:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${var.project_name}-reports-DeadLetterAlarm-*" }
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "report_dlq_email" {
  topic_arn = aws_sns_topic.report_dlq.arn
  protocol  = "email"
  endpoint  = var.report_to_email
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [confirmation_timeout_in_minutes, endpoint_auto_confirms]
  }
}

resource "aws_cloudwatch_metric_alarm" "report_dlq" {
  alarm_name          = var.report_alarm_name
  alarm_description   = "A weekly report request failed three times and needs attention."
  alarm_actions       = [aws_sns_topic.report_dlq.arn]
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    QueueName = aws_sqs_queue.report_dlq.name
  }
  depends_on = [aws_sns_topic_policy.report_dlq]
  lifecycle { prevent_destroy = true }
}

# The optional SES domain identity is absent from the live stack. It remains
# conditional so the email-only configuration does not request a new identity.
resource "aws_sesv2_email_identity" "sender_domain" {
  count          = var.sender_domain == "" ? 0 : 1
  email_identity = var.sender_domain
  tags           = { PROJECT_NAME = var.project_name }
  lifecycle { prevent_destroy = true }
}
