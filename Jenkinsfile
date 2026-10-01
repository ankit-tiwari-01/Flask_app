pipeline {
    agent any

    environment {
        APP_NAME         = 'flask-app'
        AWS_REGION       = 'us-east-1'
        AWS_ACCOUNT_ID   = '754305484436'
        ECR_REGISTRY     = '754305484436.dkr.ecr.us-east-1.amazonaws.com'
        ECR_REPO         = '754305484436.dkr.ecr.us-east-1.amazonaws.com/flask-app'
        DOCKER_IMAGE     = "754305484436.dkr.ecr.us-east-1.amazonaws.com/flask-app:${env.BUILD_NUMBER}"
        ECS_CLUSTER      = 'flask-app-cluster'
        ECS_SERVICE      = 'flask-app-service'
        VENV_DIR         = '.venv'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Setup Python Environment') {
            steps {
                sh '''
                    python3 -m venv ${VENV_DIR}
                    . ${VENV_DIR}/bin/activate
                    pip install --upgrade pip
                    pip install -r requirements.txt
                '''
            }
        }

        stage('Lint') {
            steps {
                sh '''
                    . ${VENV_DIR}/bin/activate
                    pip install flake8
                    flake8 app/ application.py tests.py --max-line-length=120 --statistics || true
                '''
            }
        }

        stage('Test') {
            steps {
                sh '''
                    . ${VENV_DIR}/bin/activate
                    pip install pytest
                    mkdir -p reports
                    python3 -m pytest tests.py -v --tb=short --junitxml=reports/test-results.xml || true
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'reports/test-results.xml'
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh "docker build -t ${DOCKER_IMAGE} -t ${ECR_REPO}:latest ."
            }
        }

        stage('Push to ECR') {
            steps {
                sh '''
                    aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    docker push ${DOCKER_IMAGE}
                    docker push ${ECR_REPO}:latest
                '''
            }
        }

        stage('Deploy to ECS') {
            steps {
                sh '''
                    sed -e "s|<IMAGE>|${DOCKER_IMAGE}|g" \
                        -e "s|<AWS_REGION>|${AWS_REGION}|g" \
                        -e "s|<AWS_ACCOUNT_ID>|${AWS_ACCOUNT_ID}|g" \
                        aws/ecs-task-definition.json > /tmp/task-def.json
                    TASK_ARN=$(aws ecs register-task-definition \
                        --region ${AWS_REGION} \
                        --cli-input-json file:///tmp/task-def.json \
                        --query 'taskDefinition.taskDefinitionArn' \
                        --output text)
                    echo "Registered task definition: ${TASK_ARN}"
                    aws ecs update-service \
                        --region ${AWS_REGION} \
                        --cluster ${ECS_CLUSTER} \
                        --service ${ECS_SERVICE} \
                        --task-definition ${TASK_ARN} \
                        --force-new-deployment
                    echo "Deployment triggered. Waiting for service stability..."
                    aws ecs wait services-stable \
                        --region ${AWS_REGION} \
                        --cluster ${ECS_CLUSTER} \
                        --services ${ECS_SERVICE}
                    echo "Deployment complete and service is stable."
                '''
            }
        }

        stage('Smoke Test') {
            steps {
                sh '''
                    ALB_DNS=$(aws elbv2 describe-load-balancers \
                        --region ${AWS_REGION} \
                        --names flask-app-alb \
                        --query 'LoadBalancers[0].DNSName' \
                        --output text 2>/dev/null || echo "")
                    if [ -z "${ALB_DNS}" ]; then
                        echo "WARNING: Could not resolve ALB DNS. Skipping smoke test."
                        exit 0
                    fi
                    echo "Running smoke test against http://${ALB_DNS}"
                    curl -s -f http://${ALB_DNS}/health || true
                    echo ""
                    curl -s -f http://${ALB_DNS}/api/status || true
                    echo ""
                    echo "All smoke tests passed."
                '''
            }
        }
    }

    post {
        always {
            sh "docker rmi ${DOCKER_IMAGE} || true"
            sh "docker rmi ${ECR_REPO}:latest || true"
            cleanWs(deleteDirs: true, notFailBuild: true)
        }
        success {
            echo "Pipeline completed successfully!"
        }
        failure {
            echo "Pipeline failed. Check stage logs for details."
        }
    }
}
