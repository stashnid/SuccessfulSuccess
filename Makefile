# ==============================================================================
# AWS & Infrastructure Configuration (Placeholder variables)
# Override via environment variables or command-line flags (e.g. make deploy-backend AWS_REGION=us-east-1)
# ==============================================================================
AWS_REGION                 ?= YOUR_AWS_REGION
AWS_ACCOUNT_ID             ?= YOUR_AWS_ACCOUNT_ID

# Frontend variables
S3_BUCKET                  ?= YOUR_S3_BUCKET
CLOUDFRONT_DISTRIBUTION_ID ?= YOUR_CLOUDFRONT_DISTRIBUTION_ID

# Backend variables
ECR_REPOSITORY             ?= YOUR_ECR_REPOSITORY
IMAGE_TAG                  ?= latest
ECS_CLUSTER                ?= YOUR_ECS_CLUSTER
ECS_SERVICE                ?= YOUR_ECS_SERVICE

ECR_REGISTRY               ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
IMAGE_URI                  ?= $(ECR_REGISTRY)/$(ECR_REPOSITORY):$(IMAGE_TAG)

.PHONY: deploy-frontend deploy-backend

# ==============================================================================
# 1. Frontend: Build static files, sync to S3 bucket, invalidate CloudFront
# ==============================================================================
deploy-frontend:
	@echo "==> Building frontend static files..."
	cd frontend && npm ci && NEXT_OUTPUT=export npm run build
	@echo "==> Syncing static files to S3: s3://$(S3_BUCKET)..."
	aws s3 sync frontend/out s3://$(S3_BUCKET) --delete
	@echo "==> Invalidating CloudFront cache for distribution: $(CLOUDFRONT_DISTRIBUTION_ID)..."
	aws cloudfront create-invalidation --distribution-id $(CLOUDFRONT_DISTRIBUTION_ID) --paths "/*"

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
