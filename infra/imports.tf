# One-time imports for the 30 resources retained from the three CloudFormation
# stacks, plus provider-specific child resources on those existing objects.
# Keep this file only until HCP Terraform completes an import-only run and a
# subsequent plan reports No changes. Never apply a create/destroy/replace plan.

# Cognito (Lab 4)
import {
  to = aws_cognito_user_pool.main
  id = "us-east-1_4nWHTc0rb"
}
import {
  to = aws_cognito_user_pool_domain.main
  id = "successfulsuccess-312209831599"
}
import {
  to = aws_cognito_identity_provider.google[0]
  id = "us-east-1_4nWHTc0rb:Google"
}
import {
  to = aws_cognito_user_pool_client.web
  id = "us-east-1_4nWHTc0rb/22rtkbmn9m1ed8cdqk18hd50cb"
}
import {
  to = aws_cognito_managed_login_branding.web
  id = "us-east-1_4nWHTc0rb,cb761d08-337d-4b2c-875c-2b1732e4b729"
}

# Weekly reports (Lab 5)
import {
  to = aws_s3_bucket.reports
  id = "successfulsuccess-reports-312209831599"
}
import {
  to = aws_s3_bucket_public_access_block.reports
  id = "successfulsuccess-reports-312209831599"
}
import {
  to = aws_s3_bucket_server_side_encryption_configuration.reports
  id = "successfulsuccess-reports-312209831599"
}
import {
  to = aws_s3_bucket_versioning.reports
  id = "successfulsuccess-reports-312209831599"
}
import {
  to = aws_s3_bucket_lifecycle_configuration.reports
  id = "successfulsuccess-reports-312209831599"
}
import {
  to = aws_s3_bucket_policy.reports
  id = "successfulsuccess-reports-312209831599"
}
import {
  to = aws_s3_bucket_notification.reports
  id = "successfulsuccess-reports-312209831599"
}
import {
  to = aws_sqs_queue.report_dlq
  id = "https://sqs.us-east-1.amazonaws.com/312209831599/successfulsuccess-report-requests-dlq"
}
import {
  to = aws_sqs_queue.report_requests
  id = "https://sqs.us-east-1.amazonaws.com/312209831599/successfulsuccess-report-requests"
}
import {
  to = aws_iam_role.builder
  id = "successfulsuccess-reports-BuilderRole-jgz2QwWuwW3S"
}
import {
  to = aws_iam_role_policy_attachment.builder_basic
  id = "successfulsuccess-reports-BuilderRole-jgz2QwWuwW3S/arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
import {
  to = aws_iam_role_policy.builder
  id = "successfulsuccess-reports-BuilderRole-jgz2QwWuwW3S:ReadQueueWriteReports"
}
import {
  to = aws_cloudwatch_log_group.builder
  id = "/aws/lambda/successfulsuccess-report-builder"
}
import {
  to = aws_lambda_function.builder
  id = "successfulsuccess-report-builder"
}
import {
  to = aws_lambda_event_source_mapping.report_queue
  id = "1e1deed8-f2a9-4a32-83a8-94e86b209fea"
}
import {
  to = aws_iam_role.scheduler
  id = "successfulsuccess-reports-SchedulerRole-OHwpQwIA8tmb"
}
import {
  to = aws_iam_role_policy.scheduler
  id = "successfulsuccess-reports-SchedulerRole-OHwpQwIA8tmb:EnqueueWeeklyReport"
}
import {
  to = aws_scheduler_schedule.weekly_report
  id = "default/successfulsuccess-weekly-report"
}
import {
  to = aws_iam_role.mailer
  id = "successfulsuccess-reports-MailerRole-3maVLijQn9IW"
}
import {
  to = aws_iam_role_policy_attachment.mailer_basic
  id = "successfulsuccess-reports-MailerRole-3maVLijQn9IW/arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
import {
  to = aws_iam_role_policy.mailer
  id = "successfulsuccess-reports-MailerRole-3maVLijQn9IW:ReadReportSendEmail"
}
import {
  to = aws_cloudwatch_log_group.mailer
  id = "/aws/lambda/successfulsuccess-report-mailer"
}
import {
  to = aws_lambda_function.mailer
  id = "successfulsuccess-report-mailer"
}
import {
  to = aws_lambda_permission.mailer_s3
  id = "successfulsuccess-report-mailer/successfulsuccess-reports-MailerInvokePermission-2tTAkOsx45eM"
}
import {
  to = aws_sns_topic.report_dlq
  id = "arn:aws:sns:us-east-1:312209831599:successfulsuccess-report-dlq-alerts"
}
import {
  to = aws_sns_topic_policy.report_dlq
  id = "arn:aws:sns:us-east-1:312209831599:successfulsuccess-report-dlq-alerts"
}
import {
  to = aws_sns_topic_subscription.report_dlq_email
  id = "arn:aws:sns:us-east-1:312209831599:successfulsuccess-report-dlq-alerts:5f8b1388-f894-45b7-ad64-efc3f5084015"
}
import {
  to = aws_cloudwatch_metric_alarm.report_dlq
  id = "successfulsuccess-reports-DeadLetterAlarm-OitVyj22z840"
}

# Agenda parser (Lab 6)
import {
  to = aws_iam_role.parser
  id = "successfulsuccess-ai-ParserRole-dXWUBXfDo2iU"
}
import {
  to = aws_iam_role_policy_attachment.parser_basic
  id = "successfulsuccess-ai-ParserRole-dXWUBXfDo2iU/arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
import {
  to = aws_iam_role_policy.parser_inference
  id = "successfulsuccess-ai-ParserRole-dXWUBXfDo2iU:BedrockMantleInference"
}
import {
  to = aws_cloudwatch_log_group.parser
  id = "/aws/lambda/successfulsuccess-agenda-parser"
}
import {
  to = aws_lambda_function.parser
  id = "successfulsuccess-agenda-parser"
}
import {
  to = aws_lambda_function_url.parser
  id = "successfulsuccess-agenda-parser"
}
import {
  to = aws_lambda_permission.parser_url
  id = "successfulsuccess-agenda-parser/successfulsuccess-ai-ParserUrlPermission-tusuZOm1E9iF"
}
import {
  to = aws_lambda_permission.parser_invoke
  id = "successfulsuccess-agenda-parser/successfulsuccess-ai-ParserInvokePermission-OnAaei67dsi6"
}
import {
  to = aws_budgets_budget.monthly
  id = "312209831599:successfulsuccess-monthly-5-usd"
}
