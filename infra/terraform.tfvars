# Non-secret values read from the three existing CloudFormation stacks on
# 2026-10-29. Set google_client_secret only as a sensitive HCP workspace variable.
aws_region   = "us-east-1"
project_name = "successfulsuccess"

app_urls = [
  "http://localhost:3000/",
  "https://d3j8i4re8dhmr8.cloudfront.net/",
]
callback_urls = [
  "http://localhost:3000/auth/callback/",
  "https://d3j8i4re8dhmr8.cloudfront.net/auth/callback/",
]
google_client_id = "408595456672-sa9hclnoipc8f37egckeia4jklvppf2t.apps.googleusercontent.com"

report_builder_image_uri = "312209831599.dkr.ecr.us-east-1.amazonaws.com/spry-backend@sha256:8bfe6874b5f0a7f1327a130b8fc3dae3b46e3ac2fd23242a708ce38dbaa5a731"
parser_image_uri         = "312209831599.dkr.ecr.us-east-1.amazonaws.com/spry-backend@sha256:b5f54b55533e0e3439f282d43f97afb894154fc737ba8e956494b3d21d8dcd89"
database_secret_arn      = "arn:aws:secretsmanager:us-east-1:312209831599:secret:successfulsuccess-db-credentials-jp0KIa"
mailer_code_bucket       = "successfulsuccess-artifacts-312209831599"
mailer_code_key          = "lab5-free-plan/mailer-logging.zip"
report_from_email        = "hnidyk.pn@ucu.edu.ua"
report_to_email          = "hnidyk.pn@ucu.edu.ua"
schedule_expression      = "cron(0 7 ? * MON *)"
schedule_target          = "SQS"

cognito_user_pool_id = "us-east-1_4nWHTc0rb"
cognito_client_id    = "22rtkbmn9m1ed8cdqk18hd50cb"
site_origin          = "https://d3j8i4re8dhmr8.cloudfront.net"
budget_email         = "hnidyk.pn@ucu.edu.ua"

parser_role_name               = "successfulsuccess-ai-ParserRole-dXWUBXfDo2iU"
parser_url_statement_id        = "successfulsuccess-ai-ParserUrlPermission-tusuZOm1E9iF"
parser_invoke_statement_id     = "successfulsuccess-ai-ParserInvokePermission-OnAaei67dsi6"
builder_role_name              = "successfulsuccess-reports-BuilderRole-jgz2QwWuwW3S"
mailer_role_name               = "successfulsuccess-reports-MailerRole-3maVLijQn9IW"
scheduler_role_name            = "successfulsuccess-reports-SchedulerRole-OHwpQwIA8tmb"
report_alarm_name              = "successfulsuccess-reports-DeadLetterAlarm-OitVyj22z840"
mailer_permission_statement_id = "successfulsuccess-reports-MailerInvokePermission-2tTAkOsx45eM"
reports_notification_id        = "Y2U2OTc1MGEtMTU2Zi00YjJhLWEwYzctMzk2YWQyNTc3MTZi"
