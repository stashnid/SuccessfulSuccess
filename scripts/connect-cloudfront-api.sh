#!/usr/bin/env bash
set -euo pipefail

# Route same-origin /api/* requests to the existing ECS ALB. The API still
# validates Cognito access tokens; CloudFront must forward Authorization and
# never cache user-specific responses.
distribution="${CLOUDFRONT_DISTRIBUTION_ID:-E1JHP5CPE2153L}"
alb_domain="${API_ALB_DOMAIN:-spry-backend-alb-1470332417.us-east-1.elb.amazonaws.com}"
origin_id="successfulsuccess-api-alb"

umask 077
work_dir="$(mktemp -d "${TMPDIR:-/private/tmp}/successfulsuccess-cloudfront.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

aws cloudfront get-distribution-config --id "$distribution" --output json > "$work_dir/current.json"
etag="$(jq -r '.ETag' "$work_dir/current.json")"

jq --arg origin "$origin_id" --arg domain "$alb_domain" '
  .DistributionConfig
  | .Origins.Items = ((.Origins.Items // []) | map(select(.Id != $origin)) + [{
      Id: $origin,
      DomainName: $domain,
      OriginPath: "",
      CustomHeaders: {Quantity: 0},
      CustomOriginConfig: {
        HTTPPort: 8000,
        HTTPSPort: 443,
        OriginProtocolPolicy: "http-only",
        OriginSslProtocols: {Quantity: 1, Items: ["TLSv1.2"]},
        OriginReadTimeout: 30,
        OriginKeepaliveTimeout: 5
      },
      ConnectionAttempts: 3,
      ConnectionTimeout: 10,
      OriginShield: {Enabled: false}
    }])
  | .Origins.Quantity = (.Origins.Items | length)
  | .DefaultCacheBehavior as $default
  | .CacheBehaviors.Items = ((.CacheBehaviors.Items // []) | map(select(.PathPattern != "/api/*")) + [
      $default + {
        PathPattern: "/api/*",
        TargetOriginId: $origin,
        ViewerProtocolPolicy: "redirect-to-https",
        AllowedMethods: {
          Quantity: 7,
          Items: ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"],
          CachedMethods: {Quantity: 2, Items: ["GET", "HEAD"]}
        },
        CachePolicyId: "4135ea2d-6df8-44a3-9df3-4b5a84be39ad",
        OriginRequestPolicyId: "b689b0a8-53d0-40ab-baf2-68738e2966ac"
      }
    ])
  | .CacheBehaviors.Quantity = (.CacheBehaviors.Items | length)
' "$work_dir/current.json" > "$work_dir/updated.json"

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  jq '{Origins: [.Origins.Items[].Id], Behaviors: [.CacheBehaviors.Items[] | {
    PathPattern, TargetOriginId, CachePolicyId, OriginRequestPolicyId,
    AllowedMethods: .AllowedMethods.Items
  }]}' "$work_dir/updated.json"
  exit 0
fi

aws cloudfront update-distribution --id "$distribution" --if-match "$etag" \
  --distribution-config "file://$work_dir/updated.json" \
  --query 'Distribution.{Id:Id,Status:Status,DomainName:DomainName}' --output json

aws cloudfront wait distribution-deployed --id "$distribution"
echo "CloudFront routes /api/* to $alb_domain:8000 without caching."
