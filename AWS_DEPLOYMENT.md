# AWS Deployment Guide — Flask App on ECS Fargate

This document provides a **complete step-by-step guide** to deploy this Flask application on **AWS ECS Fargate** with an **Application Load Balancer (ALB)**, **RDS PostgreSQL**, and a **Jenkins CI/CD pipeline**.

---

## Architecture Overview

```
                        ┌─────────────────────────────────────────────────────┐
                        │                      AWS Cloud                      │
                        │                                                     │
  Internet              │    ┌──────────────────────────────────────────┐     │
     │                  │    │               VPC (10.0.0.0/16)          │     │
     │                  │    │                                          │     │
     │                  │    │   Public Subnets                         │     │
     │                  │    │   ┌─────────────────────────────┐        │     │
     └──────────────────┼───►│   │   Application Load Balancer │        │     │
                        │    │   │       (HTTP/HTTPS :80/443)  │        │     │
                        │    │   └──────────┬──────────────────┘        │     │
                        │    │              │                           │     │
                        │    │   Private Subnets                        │     │
                        │    │   ┌──────────▼──────────────────┐        │     │
                        │    │   │   ECS Fargate Service        │        │     │
                        │    │   │   ┌────────┐  ┌────────┐    │        │     │
                        │    │   │   │ Task 1 │  │ Task 2 │    │        │     │
                        │    │   │   │ :8080  │  │ :8080  │    │        │     │
                        │    │   │   └────┬───┘  └────┬───┘    │        │     │
                        │    │   └────────┼───────────┼────────┘        │     │
                        │    │            │           │                  │     │
                        │    │   ┌────────▼───────────▼────────┐        │     │
                        │    │   │    RDS PostgreSQL (5432)     │        │     │
                        │    │   │    Multi-AZ (optional)       │        │     │
                        │    │   └─────────────────────────────┘        │     │
                        │    └──────────────────────────────────────────┘     │
                        │                                                     │
                        │    ┌──────────┐  ┌───────────┐  ┌──────────────┐   │
                        │    │   ECR    │  │ CloudWatch│  │ SSM Param    │   │
                        │    │ Registry │  │   Logs    │  │   Store      │   │
                        │    └──────────┘  └───────────┘  └──────────────┘   │
                        └─────────────────────────────────────────────────────┘

  Jenkins CI/CD
  ┌─────────────────────────────────────────────────────────────────┐
  │  Checkout → Lint → Test → Docker Build → Push ECR → Deploy ECS │
  └─────────────────────────────────────────────────────────────────┘
```

---

## AWS Resources Created

| Resource               | Purpose                                           |
|------------------------|---------------------------------------------------|
| **VPC**                | Isolated network with public + private subnets     |
| **Internet Gateway**   | Public internet access for ALB                     |
| **NAT Gateway**        | Outbound internet for private subnets (ECS tasks)  |
| **ALB**                | Distributes traffic to ECS tasks, health checks    |
| **ECR**                | Private Docker image registry                      |
| **ECS Cluster**        | Fargate cluster to run containers                  |
| **ECS Service**        | Manages desired task count, rolling deployments     |
| **ECS Task Definition**| Container config, env vars, secrets, logging        |
| **RDS PostgreSQL**     | Managed database in private subnet                 |
| **SSM Parameter Store**| Secure storage for secrets (DB creds, SECRET_KEY)  |
| **CloudWatch Logs**    | Centralized container logging                      |
| **Auto Scaling**       | Scale ECS tasks on CPU/Memory thresholds            |
| **Security Groups**    | Firewall rules (ALB→ECS→RDS)                       |
| **IAM Roles**          | Least-privilege roles for ECS execution + tasks     |

---

## Prerequisites

Before starting, ensure you have:

1. **AWS Account** with admin or power-user permissions
2. **AWS CLI v2** — [Install guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
3. **Terraform ≥ 1.5** — [Install guide](https://developer.hashicorp.com/terraform/downloads)
4. **Docker** — [Install guide](https://docs.docker.com/get-docker/)
5. **Jenkins** (for CI/CD) — [Install guide](https://www.jenkins.io/doc/book/installing/)

Configure AWS CLI:
```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-east-1), Output format (json)
```

Verify:
```bash
aws sts get-caller-identity
```

---

## Step 1: Provision AWS Infrastructure (Terraform)

### 1.1 — Configure Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
aws_region       = "us-east-1"
app_name         = "flask-app"
db_username      = "flask_admin"
db_password      = "YourStrongPassword123!"   # Change this!
flask_secret_key = "YourRandomSecretKey456!"   # Change this!
```

### 1.2 — Initialize & Apply

```bash
# Option A: Use the helper script
cd ..
./scripts/setup-infrastructure.sh

# Option B: Run Terraform manually
cd terraform
terraform init
terraform plan
terraform apply
```

### 1.3 — Note the Outputs

After applying, Terraform will print:

```
ecr_repository_url = "123456789.dkr.ecr.us-east-1.amazonaws.com/flask-app"
alb_dns_name       = "flask-app-alb-123456.us-east-1.elb.amazonaws.com"
app_url            = "http://flask-app-alb-123456.us-east-1.elb.amazonaws.com"
ecs_cluster_name   = "flask-app-cluster"
ecs_service_name   = "flask-app-service"
```

Save these — you'll need them for deployment.

---

## Step 2: Build & Push Docker Image (First Time)

```bash
# Set variables
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/flask-app"

# Authenticate Docker with ECR
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${ECR_REPO}

# Build and push
docker build -t flask-app:latest -t ${ECR_REPO}:latest .
docker push ${ECR_REPO}:latest
```

Or use the deploy script:

```bash
./scripts/deploy.sh --tag latest
```

---

## Step 3: Verify the Deployment

```bash
# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names flask-app-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

# Test health endpoint
curl http://${ALB_DNS}/health
# Expected: {"status": "healthy", ...}

# Test API endpoint
curl http://${ALB_DNS}/api/status
# Expected: {"app_name": "AWS Flask Template App", "version": "1.0.0", ...}

# Open in browser
echo "Open: http://${ALB_DNS}"
```

---

## Step 4: Set Up Jenkins CI/CD Pipeline

### 4.1 — Install Required Jenkins Plugins

Go to **Manage Jenkins → Plugins → Available plugins** and install:

- Pipeline: AWS Steps
- AWS Credentials
- Docker Pipeline
- Pipeline: Stage View
- Timestamps

### 4.2 — Add Jenkins Credentials

Go to **Manage Jenkins → Credentials → System → Global credentials**:

| Credential ID     | Type             | Value                          |
|-------------------|------------------|--------------------------------|
| `aws-account-id`  | Secret text      | Your 12-digit AWS Account ID   |
| `aws-credentials` | AWS Credentials  | IAM Access Key + Secret Key    |

Use the helper script for guidance:
```bash
./scripts/setup-jenkins-credentials.sh
```

### 4.3 — Create Jenkins Pipeline Job

1. **New Item** → Enter name `flask-app` → Select **Pipeline** → OK
2. Under **Pipeline**:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/your-org/flask-app.git`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`
3. Optionally enable **GitHub hook trigger** for automatic builds
4. Click **Save**

### 4.4 — IAM Policy for Jenkins

The AWS IAM user used by Jenkins needs this policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService",
        "ecs:DescribeTasks",
        "ecs:ListTasks"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elbv2:DescribeLoadBalancers"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": [
        "arn:aws:iam::*:role/flask-app-ecs-execution-role",
        "arn:aws:iam::*:role/flask-app-ecs-task-role"
      ]
    }
  ]
}
```

---

## Step 5: Jenkins Pipeline Stages Explained

The `Jenkinsfile` defines an 8-stage pipeline:

```
┌──────────┐   ┌───────┐   ┌──────┐   ┌──────┐   ┌───────────┐   ┌──────────┐   ┌────────────┐   ┌────────────┐
│ Checkout │ → │ Setup │ → │ Lint │ → │ Test │ → │  Docker   │ → │ Push to  │ → │ Deploy to  │ → │   Smoke    │
│          │   │ Python│   │      │   │      │   │  Build    │   │   ECR    │   │    ECS     │   │   Test     │
└──────────┘   └───────┘   └──────┘   └──────┘   └───────────┘   └──────────┘   └────────────┘   └────────────┘
                                                                      ▲               ▲                ▲
                                                                      │               │                │
                                                                   main branch     main branch     main branch
                                                                     only            only            only
```

| Stage         | Runs On      | Description                                                    |
|---------------|-------------|----------------------------------------------------------------|
| Checkout      | All branches | Pulls source code from Git                                     |
| Setup Python  | All branches | Creates virtualenv, installs dependencies                      |
| Lint          | All branches | Runs flake8 code quality checks                                |
| Test          | All branches | Runs pytest, publishes JUnit results to Jenkins                |
| Docker Build  | All branches | Builds multi-stage Docker image                                |
| Push to ECR   | main only    | Authenticates with ECR, pushes image with build # + latest tag |
| Deploy to ECS | main only    | Registers new task definition, updates ECS service, waits      |
| Smoke Test    | main only    | Hits /health and /api/status on ALB to verify deployment       |

---

## Project File Structure

```
flask_app/
├── app/
│   ├── __init__.py              # Flask app factory
│   ├── config.py                # Config with RDS/env support
│   ├── routes.py                # Routes: /, /health, /api/status
│   ├── static/                  # CSS, JS assets
│   └── templates/               # Jinja2 HTML templates
├── aws/
│   └── ecs-task-definition.json # ECS task def template (used by Jenkins)
├── terraform/
│   ├── main.tf                  # All AWS resources (VPC, ECS, RDS, ALB...)
│   ├── variables.tf             # Input variables
│   ├── outputs.tf               # Output values
│   └── terraform.tfvars.example # Example variable values
├── scripts/
│   ├── deploy.sh                # Manual deployment script
│   ├── setup-infrastructure.sh  # Terraform wrapper script
│   └── setup-jenkins-credentials.sh  # Jenkins setup guide
├── application.py               # WSGI entry point
├── requirements.txt             # Python dependencies
├── Dockerfile                   # Multi-stage Docker build
├── Jenkinsfile                  # CI/CD pipeline definition
├── .dockerignore                # Docker build exclusions
├── .gitignore                   # Git exclusions
└── AWS_DEPLOYMENT.md            # This file
```

---

## Monitoring & Operations

### View Logs

```bash
# Stream ECS container logs
aws logs tail /ecs/flask-app --follow --region us-east-1

# View last 100 log events
aws logs tail /ecs/flask-app --since 1h --region us-east-1
```

### Check ECS Service Status

```bash
aws ecs describe-services \
  --cluster flask-app-cluster \
  --services flask-app-service \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Deployments:deployments[*].{Status:status,Running:runningCount,Desired:desiredCount}}' \
  --output table
```

### Scale Manually

```bash
# Scale to 4 tasks
aws ecs update-service \
  --cluster flask-app-cluster \
  --service flask-app-service \
  --desired-count 4
```

### Rollback

```bash
# List recent task definitions
aws ecs list-task-definitions \
  --family-prefix flask-app-task \
  --sort DESC \
  --max-items 5

# Rollback to a previous task definition
aws ecs update-service \
  --cluster flask-app-cluster \
  --service flask-app-service \
  --task-definition flask-app-task:<PREVIOUS_REVISION> \
  --force-new-deployment
```

---

## Tear Down

To destroy all AWS resources and stop incurring charges:

```bash
# Option A: Helper script
./scripts/setup-infrastructure.sh --destroy

# Option B: Manual
cd terraform
terraform destroy
```

> ⚠️ This will permanently delete your database, load balancer, and all related resources.

---

## Cost Estimate (us-east-1)

| Resource              | Estimated Monthly Cost |
|-----------------------|-----------------------|
| ECS Fargate (2 tasks) | ~$15–20               |
| ALB                   | ~$16 + data transfer  |
| NAT Gateway           | ~$32 + data transfer  |
| RDS db.t3.micro       | ~$15 (free tier eligible) |
| ECR                   | ~$1 (storage)         |
| CloudWatch Logs       | ~$1–5 (retention)     |
| **Total**             | **~$80–90/month**     |

> 💡 **Cost tip:** For dev/staging, reduce `desired_count` to 1 and use a single NAT Gateway.

---

## Security Best Practices Implemented

- ✅ ECS tasks run in **private subnets** (no public IPs)
- ✅ RDS is in **private subnets** with no public access
- ✅ Security groups follow **least-privilege** (ALB→ECS→RDS only)
- ✅ Secrets stored in **SSM Parameter Store** (SecureString)
- ✅ Docker runs as **non-root user** (`appuser`)
- ✅ ECR **image scanning** enabled on push
- ✅ ECS **deployment circuit breaker** with automatic rollback
- ✅ **Container health checks** at Docker + ALB level
- ✅ IAM roles follow **least-privilege** principle
- ✅ `terraform.tfvars` excluded from Git (secrets never committed)