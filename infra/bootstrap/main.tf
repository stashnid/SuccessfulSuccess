# One-time trust bridge for HCP Terraform. Its state is separate from the
# application's state and must be retained by the project operator.
variable "hcp_organization" {
  type        = string
  description = "Exact HCP Terraform organization name."
}

variable "hcp_workspace" {
  type        = string
  description = "Exact HCP Terraform workspace name for the infra root module."
}

resource "aws_iam_openid_connect_provider" "hcp" {
  url            = "https://app.terraform.io"
  client_id_list = ["aws.workload.identity"]
  lifecycle { prevent_destroy = true }
}

resource "aws_iam_role" "hcp_infra" {
  name = "successfulsuccess-hcp-terraform"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.hcp.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "app.terraform.io:aud" = "aws.workload.identity"
        }
        StringLike = {
          "app.terraform.io:sub" = "organization:${var.hcp_organization}:project:*:workspace:${var.hcp_workspace}:run_phase:*"
        }
      }
    }]
  })

  tags = { PROJECT_NAME = "successfulsuccess" }
  lifecycle { prevent_destroy = true }
}

# Generated from the no-change import plan with IAM Policy Autopilot. This
# grants read-only import permissions, not broad infrastructure write access.
resource "aws_iam_role_policy" "hcp_import" {
  name   = "successfulsuccess-hcp-import-readonly"
  role   = aws_iam_role.hcp_infra.id
  policy = file("${path.module}/import-policy.json")
}

# Scoped permission for the Lab 7 drift exercise. HCP can restore only tags
# on the agenda parser; it cannot change code, configuration or other Lambdas.
resource "aws_iam_role_policy" "hcp_parser_tags" {
  name = "successfulsuccess-hcp-parser-tags-only"
  role = aws_iam_role.hcp_infra.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "Lab7ParserTagsOnly"
      Effect   = "Allow"
      Action   = ["lambda:TagResource", "lambda:UntagResource"]
      Resource = "arn:aws:lambda:us-east-1:312209831599:function:successfulsuccess-agenda-parser"
    }]
  })
}

output "hcp_run_role_arn" {
  value = aws_iam_role.hcp_infra.arn
}
