#!/usr/bin/env bash
set -euo pipefail

# Publish the static Next.js export to the existing private S3/CloudFront site.
# Public Cognito IDs come from environment variables or Terraform outputs;
# no Google secret enters the build.
# An empty PUBLIC_API_URL makes the browser call same-origin /api/* via CloudFront.
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
region="${AWS_REGION:-us-east-1}"
account="${AWS_ACCOUNT_ID:-312209831599}"
bucket="${S3_BUCKET:-spry-frontend-stashnid}"
distribution="${CLOUDFRONT_DISTRIBUTION_ID:-E1JHP5CPE2153L}"

actual_account="$(aws sts get-caller-identity --query Account --output text)"
if [[ "$actual_account" != "$account" ]]; then
  echo "AWS account mismatch: expected $account, got $actual_account" >&2
  exit 1
fi

infra_output() {
  terraform -chdir="$root_dir/infra" output -raw "$1"
}

pool_id="${COGNITO_USER_POOL_ID:-}"
client_id="${COGNITO_CLIENT_ID:-}"
domain="${COGNITO_DOMAIN:-}"
parser_url="${PARSER_URL:-}"
[[ -n "$pool_id" ]] || pool_id="$(infra_output user_pool_id)"
[[ -n "$client_id" ]] || client_id="$(infra_output user_pool_client_id)"
[[ -n "$domain" ]] || domain="$(infra_output cognito_hosted_domain)"
[[ -n "$parser_url" ]] || parser_url="$(infra_output parser_url)"
if [[ -z "$pool_id" || -z "$client_id" || -z "$domain" || "$pool_id" == None ]]; then
  echo "Cognito outputs are missing from the environment or Terraform state" >&2
  exit 1
fi
if [[ -z "$parser_url" || "$parser_url" == None ]]; then
  echo "Parser URL is missing from the environment or Terraform state" >&2
  exit 1
fi

cd "$root_dir/frontend"
npm ci
NEXT_OUTPUT=export NEXT_TELEMETRY_DISABLED=1 \
  NEXT_PUBLIC_COGNITO_USER_POOL_ID="$pool_id" \
  NEXT_PUBLIC_COGNITO_CLIENT_ID="$client_id" \
  NEXT_PUBLIC_COGNITO_DOMAIN="$domain" \
  NEXT_PUBLIC_API_BASE_URL="${PUBLIC_API_URL:-}" \
  NEXT_PUBLIC_PARSER_URL="$parser_url" \
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
