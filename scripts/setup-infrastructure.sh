#!/bin/bash
# =============================================================================
# setup-infrastructure.sh — One-time AWS infrastructure setup
#
# This script provisions all AWS resources using Terraform.
#
# Usage:
#   ./scripts/setup-infrastructure.sh          # Plan + Apply
#   ./scripts/setup-infrastructure.sh --plan   # Plan only (dry run)
#   ./scripts/setup-infrastructure.sh --destroy # Tear down everything
#
# Prerequisites:
#   - Terraform >= 1.5.0 installed
#   - AWS CLI v2 configured with admin-level credentials
#   - terraform/terraform.tfvars populated with your values
# =============================================================================

set -euo pipefail

TERRAFORM_DIR="terraform"
ACTION="apply"

# ---- Parse arguments ----
while [[ $# -gt 0 ]]; do
  case $1 in
    --plan)    ACTION="plan"; shift ;;
    --destroy) ACTION="destroy"; shift ;;
    *)         echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "=========================================="
echo "  Flask App — Infrastructure Setup"
echo "=========================================="
echo "  Action:    ${ACTION}"
echo "  Directory: ${TERRAFORM_DIR}"
echo "=========================================="
echo ""

# ---- Validate prerequisites ----
echo "[1/4] Validating prerequisites..."

if ! command -v terraform &> /dev/null; then
  echo "ERROR: Terraform is not installed. Install from https://www.terraform.io/downloads"
  exit 1
fi

if ! command -v aws &> /dev/null; then
  echo "ERROR: AWS CLI is not installed. Install from https://aws.amazon.com/cli/"
  exit 1
fi

# Verify AWS credentials
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)
if [ -z "${AWS_ACCOUNT_ID}" ]; then
  echo "ERROR: AWS credentials not configured. Run 'aws configure' first."
  exit 1
fi
echo "     ✓ AWS Account: ${AWS_ACCOUNT_ID}"

# Check terraform.tfvars exists
if [ ! -f "${TERRAFORM_DIR}/terraform.tfvars" ]; then
  echo "ERROR: ${TERRAFORM_DIR}/terraform.tfvars not found."
  echo "       Copy the example and fill in your values:"
  echo "       cp ${TERRAFORM_DIR}/terraform.tfvars.example ${TERRAFORM_DIR}/terraform.tfvars"
  exit 1
fi
echo "     ✓ terraform.tfvars found"
echo ""

# ---- Terraform Init ----
echo "[2/4] Initializing Terraform..."
cd "${TERRAFORM_DIR}"
terraform init
echo "     ✓ Terraform initialized"
echo ""

# ---- Terraform Validate ----
echo "[3/4] Validating Terraform configuration..."
terraform validate
echo "     ✓ Terraform configuration is valid"
echo ""

# ---- Terraform Plan / Apply / Destroy ----
case ${ACTION} in
  plan)
    echo "[4/4] Running Terraform plan (dry run)..."
    terraform plan -out=tfplan
    echo ""
    echo "=========================================="
    echo "  Plan complete. Review the output above."
    echo "  To apply: terraform apply tfplan"
    echo "=========================================="
    ;;

  apply)
    echo "[4/4] Applying Terraform configuration..."
    terraform plan -out=tfplan
    echo ""
    read -p "Do you want to apply this plan? (yes/no): " CONFIRM
    if [ "${CONFIRM}" != "yes" ]; then
      echo "Aborted."
      exit 0
    fi
    terraform apply tfplan
    echo ""
    echo "=========================================="
    echo "  ✓ INFRASTRUCTURE PROVISIONED"
    echo "=========================================="
    terraform output
    echo "=========================================="
    ;;

  destroy)
    echo "[4/4] Destroying Terraform infrastructure..."
    echo ""
    echo "  WARNING: This will DELETE all AWS resources!"
    echo ""
    read -p "Are you absolutely sure? Type 'yes' to confirm: " CONFIRM
    if [ "${CONFIRM}" != "yes" ]; then
      echo "Aborted."
      exit 0
    fi
    terraform destroy
    echo ""
    echo "=========================================="
    echo "  ✓ INFRASTRUCTURE DESTROYED"
    echo "=========================================="
    ;;
esac