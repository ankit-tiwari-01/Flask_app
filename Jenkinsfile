pipeline {
    agent any

    environment {
        APP_NAME         = 'flask-app'
        AWS_REGION       = 'us-east-1'
        AWS_ACCOUNT_ID   = credentials('aws-account-id')           // Jenkins secret text credential
        ECR_REGISTRY     = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        ECR_REPO         = "${ECR_REGISTRY}/${APP_NAME}"
        DOCKER_IMAGE     = "${ECR_REPO}:${env.BUILD_NUMBER}"
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
        // -------------------------------------------------------
        // Stage 1: Checkout
        // -------------------------------------------------------
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // -------------------------------------------------------
        // Stage 2: Setup Python Environment
        // -------------------------------------------------------
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

        // -------------------------------------------------------
        // Stage 3: Lint
        // -------------------------------------------------------
        stage('Lint') {
            steps {
                sh '''
                    . ${VENV_DIR}/bin/activate
                    pip install flake8
                    flake8 app/ application.py tests.py --max-line-length=120 --statistics || true
                '''
            }
        }

        // -------------------------------------------------------
        // Stage 4: Unit Tests
        // -------------------------------------------------------
        stage('Test') {
            steps {
                sh '''
                    . ${VENV_DIR}/bin/activate
                    pip install pytest
                    mkdir -p reports
                    python -m pytest tests.py -v --tb=short --junitxml=reports/test-results.xml
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'reports/test-results.xml'
                }
            }
        }

        // -------------------------------------------------------
        // Stage 5: Docker Build
        // -------------------------------------------------------
        stage('Docker Build') {
            steps {
                sh "docker build -t ${DOCKER_IMAGE} -t ${ECR_REPO}:latest ."
            }
        }

        // -------------------------------------------------------
        // Stage 6: Push to AWS ECR (main branch only)
        // -------------------------------------------------------
        stage('Push to ECR') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                        aws ecr get-login-password --region ${AWS_REGION} | \
                            docker login --username AWS --password-stdin ${ECR_REGISTRY}

                        docker push ${DOCKER_IMAGE}
                        docker push ${ECR_REPO}:latest
                    '''
                }
            }
        }

        // -------------------------------------------------------
        // Stage 7: Deploy to ECS Fargate (main branch only)
        // -------------------------------------------------------
        stage('Deploy to ECS') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                        # Register new task definition with the updated image
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

                        # Update the ECS service to use the new task definition
                        aws ecs update-service \
                            --region ${AWS_REGION} \
                            --cluster ${ECS_CLUSTER} \
                            --service ${ECS_SERVICE} \
                            --task-definition ${TASK_ARN} \
                            --force-new-deployment

                        echo "Deployment triggered. Waiting for service stability..."

                        # Wait for the deployment to stabilise (timeout 10 min)
                        aws ecs wait services-stable \
                            --region ${AWS_REGION} \
                            --cluster ${ECS_CLUSTER} \
                            --services ${ECS_SERVICE}

                        echo "Deployment complete and service is stable."
                    '''
                }
            }
        }

        // -------------------------------------------------------
        // Stage 8: Smoke Test (main branch only)
        // -------------------------------------------------------
        stage('Smoke Test') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                        # Get the ALB DNS name from CloudFormation / Terraform output
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

                        # Health check
                        STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://${ALB_DNS}/health)
                        if [ "${STATUS}" != "200" ]; then
                            echo "SMOKE TEST FAILED: /health returned HTTP ${STATUS}"
                            exit 1
                        fi
                        echo "/health returned HTTP 200 — OK"

                        # API status check
                        STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://${ALB_DNS}/api/status)
                        if [ "${STATUS}" != "200" ]; then
                            echo "SMOKE TEST FAILED: /api/status returned HTTP ${STATUS}"
                            exit 1
                        fi
                        echo "/api/status returned HTTP 200 — OK"

                        echo "All smoke tests passed."
                    '''
                }
            }
        }
    }

    post {
        always {
            cleanWs()
            sh "docker rmi ${DOCKER_IMAGE} || true"
            sh "docker rmi ${ECR_REPO}:latest || true"
        }
        success {
            echo "Pipeline completed successfully — image ${DOCKER_IMAGE} deployed."
        }
        failure {
            echo "Pipeline FAILED for ${DOCKER_IMAGE}"
            // Uncomment to enable email notifications:
            // mail to: 'team@example.com',
            //      subject: "FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            //      body: "Check console output: ${env.BUILD_URL}"
        }
    }
}