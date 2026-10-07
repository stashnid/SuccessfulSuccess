#!/usr/bin/env bash
set -euo pipefail

# Publish the static Next.js export to the existing private S3/CloudFront site.
# Public Cognito IDs come from CloudFormation; no Google secret enters the build.
# An empty PUBLIC_API_URL makes the browser call same-origin /api/* via CloudFront.
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
region="${AWS_REGION:-us-east-1}"
account="${AWS_ACCOUNT_ID:-312209831599}"
bucket="${S3_BUCKET:-spry-frontend-stashnid}"
distribution="${CLOUDFRONT_DISTRIBUTION_ID:-E1JHP5CPE2153L}"
auth_stack="${AUTH_STACK:-successfulsuccess-auth}"

actual_account="$(aws sts get-caller-identity --query Account --output text)"
if [[ "$actual_account" != "$account" ]]; then
  echo "AWS account mismatch: expected $account, got $actual_account" >&2
  exit 1
fi

stack_output() {
  aws cloudformation describe-stacks --stack-name "$auth_stack" --region "$region" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue|[0]" --output text
}

pool_id="$(stack_output UserPoolId)"
client_id="$(stack_output UserPoolClientId)"
domain="$(stack_output HostedDomain)"
if [[ -z "$pool_id" || -z "$client_id" || -z "$domain" || "$pool_id" == None ]]; then
  echo "Cognito outputs are missing from $auth_stack" >&2
  exit 1
fi

cd "$root_dir/frontend"
npm ci
NEXT_OUTPUT=export NEXT_TELEMETRY_DISABLED=1 \
  NEXT_PUBLIC_COGNITO_USER_POOL_ID="$pool_id" \
  NEXT_PUBLIC_COGNITO_CLIENT_ID="$client_id" \
  NEXT_PUBLIC_COGNITO_DOMAIN="$domain" \
  NEXT_PUBLIC_API_BASE_URL="${PUBLIC_API_URL:-}" \
  npm run build -- --webpack

aws s3 sync out "s3://$bucket/" --exclude '.gitkeep' --delete --only-show-errors

# S3 origins do not resolve /privacy/ to /privacy/index.html automatically.
# Give each static route an object at its exact trailing-slash URL.
while IFS= read -r -d '' page; do
  route="${page#out/}"
  route="${route%/index.html}"
  aws s3api put-object --bucket "$bucket" --key "$route/" --body "$page" \
    --content-type 'text/html; charset=utf-8' --cache-control 'max-age=60' \
    --query ETag --output text >/dev/null
done < <(find out -mindepth 2 -type f -name index.html -print0)

aws cloudfront create-invalidation --distribution-id "$distribution" --paths '/*' \
  --query 'Invalidation.{Id:Id,Status:Status}' --output json
