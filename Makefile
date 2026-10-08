# ==============================================================================
# AWS & Infrastructure Configuration (Placeholder variables)
# Override via environment variables or command-line flags (e.g. make deploy-backend AWS_REGION=us-east-1)
# ==============================================================================
AWS_REGION                 ?= us-east-1
AWS_ACCOUNT_ID             ?= 312209831599

# Frontend variables
S3_BUCKET                  ?= spry-frontend-stashnid
CLOUDFRONT_DISTRIBUTION_ID ?= E1JHP5CPE2153L

# Backend variables
ECR_REPOSITORY             ?= spry-backend
IMAGE_TAG                  ?= latest
ECS_CLUSTER                ?= spry-cluster
ECS_SERVICE                ?= spry-service

ECR_REGISTRY               ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
IMAGE_URI                  ?= $(ECR_REGISTRY)/$(ECR_REPOSITORY):$(IMAGE_TAG)

.PHONY: deploy-frontend deploy-backend connect-api configure-backend-auth report-now report-objects

# Lab 3 stretch: publish a same-origin /api/* route and configure the running
# backend to verify Cognito access tokens. Neither target rebuilds the image.
connect-api:
	CLOUDFRONT_DISTRIBUTION_ID=$(CLOUDFRONT_DISTRIBUTION_ID) bash scripts/connect-cloudfront-api.sh

configure-backend-auth:
	AWS_REGION=$(AWS_REGION) AWS_ACCOUNT_ID=$(AWS_ACCOUNT_ID) \
	ECS_CLUSTER=$(ECS_CLUSTER) ECS_SERVICE=$(ECS_SERVICE) bash scripts/deploy-ecs-auth.sh

# ==============================================================================
# 1. Frontend: Build static files, sync to S3 bucket, invalidate CloudFront
# ==============================================================================
deploy-frontend:
	AWS_REGION=$(AWS_REGION) AWS_ACCOUNT_ID=$(AWS_ACCOUNT_ID) \
	S3_BUCKET=$(S3_BUCKET) CLOUDFRONT_DISTRIBUTION_ID=$(CLOUDFRONT_DISTRIBUTION_ID) \
	PUBLIC_API_URL="$(PUBLIC_API_URL)" bash scripts/deploy-frontend.sh

# ==============================================================================
# 2. Backend: Build Docker image, push to ECR, force new deployment on ECS Fargate
# ==============================================================================
deploy-backend:
	@echo "==> Building backend Docker image: $(IMAGE_URI)..."
	docker build -t $(IMAGE_URI) ./backend
	@echo "==> Authenticating Docker with Amazon ECR..."
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ECR_REGISTRY)
	@echo "==> Pushing Docker image to ECR..."
	docker push $(IMAGE_URI)
	@echo "==> Forcing new deployment on ECS Fargate service $(ECS_SERVICE) in cluster $(ECS_CLUSTER)..."
	aws ecs update-service --cluster $(ECS_CLUSTER) --service $(ECS_SERVICE) --force-new-deployment --region $(AWS_REGION)

# Weekly reports stack: manual trigger and submission evidence.
REPORTS_STACK ?= successfulsuccess-reports
REPORTS_BUCKET ?= successfulsuccess-reports-$(AWS_ACCOUNT_ID)

report-now:
	@case "$(WEEK)" in ????-W??) ;; *) echo 'Usage: make report-now WEEK=2026-W40' >&2; exit 2;; esac
	@queue_url=$$(aws cloudformation describe-stacks --stack-name "$(REPORTS_STACK)" --region "$(AWS_REGION)" --query 'Stacks[0].Outputs[?OutputKey==`ReportQueueUrl`].OutputValue | [0]' --output text) && \
	aws sqs send-message --region "$(AWS_REGION)" --queue-url "$$queue_url" \
	  --message-body "$$(printf '{"week":"%s","source":"report-now"}' '$(WEEK)')"

report-objects:
	aws s3 ls "s3://$(REPORTS_BUCKET)/reports/" --recursive --region "$(AWS_REGION)"
