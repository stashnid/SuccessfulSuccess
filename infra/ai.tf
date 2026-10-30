# Existing Lab 6 stack. Physical IDs and provider import support must be
# checked before any apply; this file only describes the present configuration.
resource "aws_iam_role" "parser" {
  name = var.parser_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = { PROJECT_NAME = var.project_name }

  lifecycle { prevent_destroy = true }
}

resource "aws_iam_role_policy_attachment" "parser_basic" {
  role       = aws_iam_role.parser.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "parser_inference" {
  name = "BedrockMantleInference"
  role = aws_iam_role.parser.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["bedrock:InvokeModel", "bedrock-mantle:CreateInference"]
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "parser" {
  name              = "/aws/lambda/${var.project_name}-agenda-parser"
  retention_in_days = 7
  tags              = { PROJECT_NAME = var.project_name }
  lifecycle { prevent_destroy = true }
}

resource "aws_lambda_function" "parser" {
  function_name = "${var.project_name}-agenda-parser"
  package_type  = "Image"
  image_uri     = var.parser_image_uri
  architectures = ["arm64"]
  role          = aws_iam_role.parser.arn
  memory_size   = 512
  timeout       = 30

  image_config {
    command = ["app.ai.agenda_lambda.handler"]
  }

  logging_config {
    log_group  = aws_cloudwatch_log_group.parser.name
    log_format = "Text"
  }

  environment {
    variables = {
      COGNITO_REGION       = var.aws_region
      COGNITO_USER_POOL_ID = var.cognito_user_pool_id
      COGNITO_CLIENT_ID    = var.cognito_client_id
      PARSER_MODEL         = var.parser_model
    }
  }

  tags = {
    PROJECT_NAME  = var.project_name
    LAB7_WORKFLOW = "reviewed"
  }
  lifecycle { prevent_destroy = true }
}

resource "aws_lambda_function_url" "parser" {
  function_name      = aws_lambda_function.parser.function_name
  authorization_type = "NONE"
  invoke_mode        = "BUFFERED"

  cors {
    allow_origins = [var.site_origin]
    allow_methods = ["POST"]
    allow_headers = ["authorization", "content-type"]
    max_age       = 300
  }

  lifecycle { prevent_destroy = true }
}

resource "aws_lambda_permission" "parser_url" {
  statement_id           = var.parser_url_statement_id
  function_name          = aws_lambda_function.parser.function_name
  action                 = "lambda:InvokeFunctionUrl"
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "parser_invoke" {
  statement_id             = var.parser_invoke_statement_id
  function_name            = aws_lambda_function.parser.function_name
  action                   = "lambda:InvokeFunction"
  principal                = "*"
  invoked_via_function_url = true
}

resource "aws_budgets_budget" "monthly" {
  name         = "${var.project_name}-monthly-5-usd"
  budget_type  = "COST"
  time_unit    = "MONTHLY"
  limit_amount = "5"
  limit_unit   = "USD"

  notification {
    notification_type          = "ACTUAL"
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.budget_email]
  }

  lifecycle { prevent_destroy = true }
}
