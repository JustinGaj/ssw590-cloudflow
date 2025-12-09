pipeline {
    agent {
        docker {
            image 'node:20-bullseye'
            // Use the standard Docker image as a separate service for DinD
            // The 'docker:dind' image is designed to run its own Docker daemon,
            // bypassing host incompatibility issues like GLIBC.
            args '--privileged'
            label 'node-agent'
            service('docker:dind')
        }
    }

    environment {
        IMAGE = 'cloudflowstocks/web' 
        VERSION_BASE = '1.0' 
        WORKSPACE_PATH = '/var/jenkins_home/workspace/cloudflow-pipeline' 
        // CRITICAL: Set the Docker host environment variable to point to the DinD service
        DOCKER_HOST = 'tcp://docker:2376'
        DOCKER_CERT_PATH = '/certs/client' // Required for TLS
        DOCKER_TLS_VERIFY = '1' // Required for TLS
    }

    stages {
        // ... (Checkout Code and Install & Test stages are mostly unchanged, but now run against DinD) ...
        stage('Checkout Code') {
            steps {
                script {
                    echo "Cleaning workspace to resolve file path issues..."
                    cleanWs() 
                    checkout scm 
                }
            }
        }

        stage('Install & Test') {
            steps {
                sh '''
                    echo "Running npm install and tests inside the Node container."
                    npm install
                    echo "Starting app in background..."
                    npm start &
                    APP_PID=$!
                    sleep 3
                    echo "Running automated tests..."
                    npm test
                    TEST_STATUS=$?
                    kill $APP_PID
                    exit $TEST_STATUS
                '''
            }
        }

        // Stage 3: Build the Docker Image (Now using the DOCKER_HOST service)
        stage('Build & Version Image') {
            steps {
                script {
                    def changelist = sh(script: "git rev-list --count HEAD", returnStdout: true).trim()
                    env.TAG = "${VERSION_BASE}.${changelist}"
                    echo "Building Version: ${env.TAG}"
                    
                    // Uses the DOCKER_HOST environment variable to talk to the DinD service
                    sh "docker build -t ${IMAGE}:${env.TAG} ."
                }
            }
        }

        // Stage 4: Compile LaTeX documentation (Simplified to rely on the agent's workspace)
        stage('Compile LaTeX') {
            agent {
                docker {
                    image 'blang/latex:latest'
                    label 'latex-agent'
                }
            }
            steps {
                // Command runs directly inside the 'blang/latex:latest' container
                sh 'pdflatex latex.tex || echo "LaTeX failed but continuing build"'
            }
        }

        // Stage 5: Package the deployable artifact (Unchanged)
        stage('Package Artifact') {
            steps {
                sh """
                    echo "Version: ${env.TAG}" > VERSION.txt
                    zip -r deployment-${env.TAG}.zip index.js package.json VERSION.txt latex.pdf
                """
                archiveArtifacts artifacts: "*.zip", fingerprint: true
            }
        }

        // Stage 6: Deploy to the host (Now using the DOCKER_HOST service)
        stage('Deploy') {
            steps {
                echo "Deploying container ${IMAGE}:${env.TAG}"
                // Uses the DOCKER_HOST environment variable to talk to the DinD service
                // NOTE: We change the exposed port from 80:8080 to 8080:8080 to avoid host port conflicts
                sh """
                    docker stop site-container || true
                    docker rm site-container || true
                    docker run -d --name site-container -p 8080:8080 ${IMAGE}:${env.TAG}
                """
            }
        }
    }

    post {
        success {
            echo "------------------------------------------------"
            echo "DEMO SUCCESS: Version ${env.TAG} is live! 🎉"
            echo "------------------------------------------------"
        }
        failure {
            echo "------------------------------------------------"
            echo "DEMO FAILED: Check logs for the latest stage failure. 🛑"
            echo "------------------------------------------------"
        }
        always {
            echo "Pipeline finished on ${new Date().format('yyyy-MM-dd HH:mm:ss')}"
        }
    }
}