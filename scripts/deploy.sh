#!/bin/bash
# =============================================================================
# deploy.sh — Full deployment script for AWS ECS Fargate
#
# Usage:
#   ./scripts/deploy.sh                  # Deploy with default settings
#   ./scripts/deploy.sh --region us-west-2 --tag v1.2.3
#
# Prerequisites:
#   - AWS CLI v2 configured with appropriate credentials
#   - Docker installed and running
#   - Terraform infrastructure already provisioned
# =============================================================================

set -euo pipefail

# ---- Determine Project Root (ensure script runs from project root) ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

# ---- Default Configuration ----
AWS_REGION="${AWS_REGION:-us-east-1}"
APP_NAME="${APP_NAME:-flask-app}"
ECS_CLUSTER="${ECS_CLUSTER:-flask-app-cluster}"
ECS_SERVICE="${ECS_SERVICE:-flask-app-service}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# ---- Parse arguments ----
while [[ $# -gt 0 ]]; do
  case $1 in
    --region) AWS_REGION="$2"; shift 2 ;;
    --tag)    IMAGE_TAG="$2"; shift 2 ;;
    --app)    APP_NAME="$2"; shift 2 ;;
    *)        echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ---- Derived variables ----
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_REPO="${ECR_REGISTRY}/${APP_NAME}"
FULL_IMAGE="${ECR_REPO}:${IMAGE_TAG}"

echo "=========================================="
echo "  Flask App — AWS ECS Deployment"
echo "=========================================="
echo "  Region:     ${AWS_REGION}"
echo "  App:        ${APP_NAME}"
echo "  Image Tag:  ${IMAGE_TAG}"
echo "  ECR Repo:   ${ECR_REPO}"
echo "  Cluster:    ${ECS_CLUSTER}"
echo "  Service:    ${ECS_SERVICE}"
echo "=========================================="
echo ""

# ---- Step 1: Authenticate Docker with ECR ----
echo "[1/6] Authenticating Docker with ECR..."
aws ecr get-login-password --region "${AWS_REGION}" | \
  docker login --username AWS --password-stdin "${ECR_REGISTRY}"
echo "     ✓ Docker authenticated with ECR"
echo ""

# ---- Step 2: Build Docker image ----
echo "[2/6] Building Docker image..."
docker build -t "${APP_NAME}:${IMAGE_TAG}" -t "${FULL_IMAGE}" .
echo "     ✓ Docker image built: ${FULL_IMAGE}"
echo ""

# ---- Step 3: Push to ECR ----
echo "[3/6] Pushing image to ECR..."
docker push "${FULL_IMAGE}"

# Also push as 'latest'
docker tag "${FULL_IMAGE}" "${ECR_REPO}:latest"
docker push "${ECR_REPO}:latest"
echo "     ✓ Image pushed to ECR"
echo ""

# ---- Step 4: Update ECS Task Definition ----
echo "[4/6] Registering new ECS task definition..."

# Get current task definition and update the image
CURRENT_TASK_DEF=$(aws ecs describe-services \
  --region "${AWS_REGION}" \
  --cluster "${ECS_CLUSTER}" \
  --services "${ECS_SERVICE}" \
  --query 'services[0].taskDefinition' \
  --output text)

# Get the full task definition JSON, update the image, and strip read-only fields
aws ecs describe-task-definition \
  --region "${AWS_REGION}" \
  --task-definition "${CURRENT_TASK_DEF}" \
  --query 'taskDefinition' | \
  python3 -c "
import json, sys
td = json.load(sys.stdin)
td['containerDefinitions'][0]['image'] = '${FULL_IMAGE}'
# Remove read-only fields that cannot be passed to register-task-definition
for key in ['taskDefinitionArn', 'revision', 'status', 'requiresAttributes', 'compatibilities', 'registeredAt', 'registeredBy']:
    td.pop(key, None)
print(json.dumps(td))
" > /tmp/new-task-def.json

NEW_TASK_ARN=$(aws ecs register-task-definition \
  --region "${AWS_REGION}" \
  --cli-input-json file:///tmp/new-task-def.json \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "     ✓ Registered task definition: ${NEW_TASK_ARN}"
echo ""

# ---- Step 5: Update ECS Service ----
echo "[5/6] Updating ECS service..."
aws ecs update-service \
  --region "${AWS_REGION}" \
  --cluster "${ECS_CLUSTER}" \
  --service "${ECS_SERVICE}" \
  --task-definition "${NEW_TASK_ARN}" \
  --force-new-deployment \
  --query 'service.serviceName' \
  --output text > /dev/null

echo "     ✓ ECS service update triggered"
echo ""

# ---- Step 6: Wait for service stability ----
echo "[6/6] Waiting for deployment to stabilise (this may take a few minutes)..."
aws ecs wait services-stable \
  --region "${AWS_REGION}" \
  --cluster "${ECS_CLUSTER}" \
  --services "${ECS_SERVICE}"

# Get the ALB DNS
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --region "${AWS_REGION}" \
  --names "${APP_NAME}-alb" \
  --query 'LoadBalancers[0].DNSName' \
  --output text 2>/dev/null || echo "(could not resolve)")

echo ""
echo "=========================================="
echo "  ✓ DEPLOYMENT COMPLETE"
echo "=========================================="
echo "  Image:    ${FULL_IMAGE}"
echo "  Task Def: ${NEW_TASK_ARN}"
echo "  App URL:  http://${ALB_DNS}"
echo "  Health:   http://${ALB_DNS}/health"
echo "=========================================="