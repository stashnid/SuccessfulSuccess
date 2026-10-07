#!/usr/bin/env bash
set -euo pipefail

# Update the existing ECS task without printing its DATABASE_URL. Cognito
# identifiers come from the deployed auth stack, not from local secrets.
region="${AWS_REGION:-us-east-1}"
account="${AWS_ACCOUNT_ID:-312209831599}"
cluster="${ECS_CLUSTER:-spry-cluster}"
service="${ECS_SERVICE:-spry-service}"
auth_stack="${AUTH_STACK:-successfulsuccess-auth}"
website_origin="${WEBSITE_ORIGIN:-https://d3j8i4re8dhmr8.cloudfront.net}"

if [[ "$(aws sts get-caller-identity --query Account --output text)" != "$account" ]]; then
  echo "AWS account does not match $account" >&2
  exit 1
fi

stack_output() {
  aws cloudformation describe-stacks --stack-name "$auth_stack" --region "$region" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue|[0]" --output text
}

pool_id="$(stack_output UserPoolId)"
client_id="$(stack_output UserPoolClientId)"
if [[ -z "$pool_id" || -z "$client_id" || "$pool_id" == None || "$client_id" == None ]]; then
  echo "Cognito outputs are missing from $auth_stack" >&2
  exit 1
fi

previous_task="$(aws ecs describe-services --cluster "$cluster" --services "$service" \
  --region "$region" --query 'services[0].taskDefinition' --output text)"
if [[ "$previous_task" == None || -z "$previous_task" ]]; then
  echo "ECS service $service was not found" >&2
  exit 1
fi

# The AWS CLI needs a regular JSON file for --cli-input-json. Limit it to the
# current user, delete it on every exit, and never include it in the repository.
umask 077
input_json="$(mktemp "${TMPDIR:-/private/tmp}/successfulsuccess-task.XXXXXX")"
trap 'rm -f "$input_json"' EXIT
aws ecs describe-task-definition --task-definition "$previous_task" \
  --region "$region" --query taskDefinition --output json | \
  jq --arg region "$region" --arg pool "$pool_id" --arg client "$client_id" \
     --arg origin "$website_origin" '
    {
      family, taskRoleArn, executionRoleArn, networkMode,
      containerDefinitions, volumes, placementConstraints,
      requiresCompatibilities, cpu, memory, runtimePlatform, ephemeralStorage
    }
    | with_entries(select(.value != null))
    | .containerDefinitions |= map(
        if .name == "backend" then
          .environment = (
            (.environment // [])
            | map(select(.name as $name |
                ["COGNITO_REGION", "COGNITO_USER_POOL_ID", "COGNITO_CLIENT_ID", "CORS_ORIGINS"]
                | index($name) | not))
            + [
              {name: "COGNITO_REGION", value: $region},
              {name: "COGNITO_USER_POOL_ID", value: $pool},
              {name: "COGNITO_CLIENT_ID", value: $client},
              {name: "CORS_ORIGINS", value: $origin}
            ]
          )
        else . end
      )
  ' > "$input_json"
new_task="$(aws ecs register-task-definition --cli-input-json "file://$input_json" \
  --region "$region" --query 'taskDefinition.taskDefinitionArn' --output text)"
rm -f "$input_json"

echo "Registered $new_task with Cognito settings. Updating $service..."
aws ecs update-service --cluster "$cluster" --service "$service" \
  --task-definition "$new_task" --region "$region" \
  --query 'service.{taskDefinition:taskDefinition,desiredCount:desiredCount}' --output json

if ! aws ecs wait services-stable --cluster "$cluster" --services "$service" --region "$region"; then
  echo "New task did not stabilize. Restoring $previous_task..." >&2
  aws ecs update-service --cluster "$cluster" --service "$service" \
    --task-definition "$previous_task" --region "$region" \
    --query 'service.taskDefinition' --output text >&2
  exit 1
fi

echo "ECS service is stable on $new_task"
