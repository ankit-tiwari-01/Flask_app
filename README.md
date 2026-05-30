# Production Flask Application for AWS Deployment

A premium, modular Flask application template fully optimized and structured for production deployment on **Amazon Web Services (AWS)**. It contains built-in configurations for environment-based configuration, production web-serving (`gunicorn`), health checks for load-balancers, and a beautiful system dashboard.

## 🚀 Quick Start (Local Development)

### 1. Prerequisites
- Python 3.10 or 3.11
- Git

### 2. Setup environment
Initialize a python virtual environment, activate it, and install dependencies:

```bash
# Create virtual environment
python -m venv venv

# Activate it (Windows PowerShell)
.\venv\Scripts\Activate.ps1

# Activate it (Mac/Linux)
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 3. Run Locally
Create a `.env` file in the root directory (optional, overrides defaults):
```env
FLASK_ENV=development
FLASK_DEBUG=True
SECRET_KEY=highly-secure-custom-key-for-local
PORT=5000
```

Start the Flask application:
```bash
python application.py
```
Open your browser and navigate to `http://localhost:5000`.

---

## ☁️ AWS Deployment Blueprints

This project includes configurations for the top three AWS hosting pathways:

### Option A: AWS Elastic Beanstalk (Recommended for fast setup)
Elastic Beanstalk automatically provisions resources like load balancers, auto-scaling groups, and EC2 instances.

#### Setup & Deployment:
1. Install the Elastic Beanstalk CLI (`awsebcli`):
   ```bash
   pip install awsebcli
   ```
2. Initialize your project (select your region and choose **Python 3.11** or **Python 3.10** as the platform):
   ```bash
   eb init -p python-3.11 my-flask-app
   ```
3. (Optional) Configure SSH access if requested.
4. Create the environment (this will provision a Load Balancer and security groups):
   ```bash
   eb create flask-env
   ```
5. Deploy code updates in the future using:
   ```bash
   eb deploy
   ```
6. Open your browser to view the application:
   ```bash
   eb open
   ```

*Note: Elastic Beanstalk reads `requirements.txt` to install dependencies and uses the entry point object `application` in `application.py` automatically.*

---

### Option B: AWS App Runner (Recommended for containerized apps)
AWS App Runner is a fully managed service that makes it easy to build, deploy, and scale containerized web applications.

#### Setup & Deployment:
1. Build the Docker container locally to verify:
   ```bash
   docker build -t flask-aws-app .
   ```
2. Authenticate Docker with Amazon ECR (Elastic Container Registry):
   ```bash
   aws ecr get-login-password --region <your-region> | docker login --username AWS --password-stdin <aws_account_id>.dkr.ecr.<your-region>.amazonaws.com
   ```
3. Create an ECR repository and tag your image:
   ```bash
   aws ecr create-repository --repository-name flask-aws-app
   docker tag flask-aws-app:latest <aws_account_id>.dkr.ecr.<your-region>.amazonaws.com/flask-aws-app:latest
   ```
4. Push your image to ECR:
   ```bash
   docker push <aws_account_id>.dkr.ecr.<your-region>.amazonaws.com/flask-aws-app:latest
   ```
5. Go to the **AWS App Runner Console**:
   - Choose **Create Service**.
   - Select **Container registry** -> **Amazon ECR**.
   - Select the `flask-aws-app` repository and `latest` tag.
   - Choose deployment trigger: **Automatic** (for CI/CD) or **Manual**.
   - In **Configure service**: Set port to **`8080`** (which matches the Dockerfile exposed port).
   - In **Health check**: Use Path `/health`, Interval 5s, Timeout 2s, Healthy threshold 1.
   - Review and deploy!

---

### Option C: AWS ECS Fargate (Serverless Container Orchestration)
ECS Fargate allows you to run serverless containers with granular control over networking (VPCs, private subnets), security groups, and scaling.

#### Setup & Deployment:
1. Build and push your Docker image to **Amazon ECR** (similar to App Runner steps 1-4 above).
2. Create a Cluster:
   ```bash
   aws ecs create-cluster --cluster-name flask-production-cluster
   ```
3. Create a **Task Definition** (you can use AWS Console or CLI). In the task definition, configure:
   - Launch type compatibility: **FARGATE**
   - Network mode: **awsvpc**
   - Task CPU & Memory (e.g. 0.25 vCPU, 0.5 GB)
   - Container mappings: Port **`8080`**, image URI pointing to your ECR image.
4. Create an Application Load Balancer (ALB):
   - Configure a **Target Group** using Protocol **HTTP**, Port **8080**, and Health Check path `/health`.
5. Create the ECS Service pointing to your ALB:
   ```bash
   aws ecs create-service \
     --cluster flask-production-cluster \
     --service-name flask-web-service \
     --task-definition <task-def-arn> \
     --desired-count 2 \
     --launch-type FARGATE \
     --network-configuration "awsvpcConfiguration={subnets=[<subnet-1>,<subnet-2>],securityGroups=[<security-group-id>],assignPublicIp=ENABLED}" \
     --load-balancers "targetGroupArn=<target-group-arn>,containerName=<container-name>,containerPort=8080"
   ```

---

## 🛠️ Project Architecture

```
flask_app/
├── app/
│   ├── __init__.py          # Flask Application Factory pattern
│   ├── config.py            # Environment-based configuration (RDS RDS_USERNAME, etc.)
│   ├── routes.py            # Main application routing, health checks, & endpoints
│   ├── templates/
│   │   ├── base.html        # Premium, responsive base template
│   │   └── index.html       # Landing page and API status dashboard
│   └── static/
│       ├── css/
│       │   └── style.css    # Modern stylesheet (HSL variables, glassmorphism, responsive)
│       └── js/
│           └── main.js      # Client-side dynamic API tester and UI controllers
├── Dockerfile               # Production multi-stage Docker build
├── .dockerignore            # Excludes temporary local environment files
├── .gitignore               # Standard git exclusions for Python & Elastic Beanstalk
├── application.py           # Entrypoint (EB reads 'application' object here)
└── requirements.txt         # Package requirements
```

## 🩺 Health Check & Load Balancers
The Application Load Balancers (ALB) on AWS send automatic HTTP ping requests to determine if your application instances are running correctly.

This template is configured with an active health endpoint:
- **Endpoint**: `/health`
- **Output**: JSON payload `{ "status": "healthy", ... }` with HTTP status code `200`.

Make sure to map this path in your AWS Target Groups or Beanstalk health check configurations to avoid deployment rolls.
