#!/bin/bash
# =============================================================================
# setup-jenkins-credentials.sh — Create SSM parameters and print
# the Jenkins credential IDs you need to configure.
#
# This is a helper script — Jenkins credentials must still be added
# through the Jenkins UI or Jenkins Configuration as Code (JCasC).
#
# Usage:
#   ./scripts/setup-jenkins-credentials.sh
#
# Prerequisites:
#   - AWS CLI v2 configured
# =============================================================================

set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "=========================================="
echo "  Jenkins Credentials Setup Guide"
echo "=========================================="
echo ""
echo "Your AWS Account ID: ${AWS_ACCOUNT_ID}"
echo "Region:              ${AWS_REGION}"
echo ""
echo "----------------------------------------------"
echo "  Required Jenkins Credentials"
echo "----------------------------------------------"
echo ""
echo "1. Credential ID:   aws-account-id"
echo "   Type:            Secret text"
echo "   Value:           ${AWS_ACCOUNT_ID}"
echo "   Description:     AWS Account ID for ECR registry"
echo ""
echo "2. Credential ID:   aws-credentials"
echo "   Type:            AWS Credentials"
echo "   Access Key ID:   <YOUR_AWS_ACCESS_KEY_ID>"
echo "   Secret Key:      <YOUR_AWS_SECRET_ACCESS_KEY>"
echo "   Description:     AWS credentials for ECR push and ECS deployment"
echo "   Plugin needed:   'AWS Credentials' Jenkins plugin"
echo ""
echo "----------------------------------------------"
echo "  Required Jenkins Plugins"
echo "----------------------------------------------"
echo ""
echo "Install these from: Manage Jenkins > Plugins > Available plugins"
echo ""
echo "  1. Pipeline: AWS Steps"
echo "  2. AWS Credentials"
echo "  3. Docker Pipeline"
echo "  4. Pipeline: Stage View"
echo "  5. Timestamps"
echo ""
echo "----------------------------------------------"
echo "  Steps to Add Credentials in Jenkins"
echo "----------------------------------------------"
echo ""
echo "  1. Navigate to: Manage Jenkins > Credentials > System > Global"
echo "  2. Click 'Add Credentials'"
echo "  3. For 'aws-account-id':"
echo "       Kind:   Secret text"
echo "       ID:     aws-account-id"
echo "       Secret: ${AWS_ACCOUNT_ID}"
echo "  4. For 'aws-credentials':"
echo "       Kind:   AWS Credentials"
echo "       ID:     aws-credentials"
echo "       Access Key ID:     <your-key>"
echo "       Secret Access Key: <your-secret>"
echo ""
echo "----------------------------------------------"
echo "  IAM Policy for Jenkins AWS User"
echo "----------------------------------------------"
echo ""
echo "The AWS user/role used by Jenkins needs these permissions:"
echo ""
echo "  - ecr:GetAuthorizationToken"
echo "  - ecr:BatchCheckLayerAvailability"
echo "  - ecr:GetDownloadUrlForLayer"
echo "  - ecr:BatchGetImage"
echo "  - ecr:PutImage"
echo "  - ecr:InitiateLayerUpload"
echo "  - ecr:UploadLayerPart"
echo "  - ecr:CompleteLayerUpload"
echo "  - ecs:DescribeServices"
echo "  - ecs:DescribeTaskDefinition"
echo "  - ecs:RegisterTaskDefinition"
echo "  - ecs:UpdateService"
echo "  - ecs:DescribeTasks"
echo "  - ecs:ListTasks"
echo "  - elbv2:DescribeLoadBalancers"
echo "  - iam:PassRole"
echo "  - logs:CreateLogStream"
echo "  - logs:PutLogEvents"
echo ""
echo "=========================================="
echo "  Setup complete. Configure Jenkins now."
echo "=========================================="