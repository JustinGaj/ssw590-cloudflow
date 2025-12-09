pipeline {
    // 1. Change top-level agent to 'none'.
    // This allows us to define the services block and per-stage agents.
    agent none 

    environment {
        IMAGE = 'cloudflowstocks/web' 
        VERSION_BASE = '1.0' 
        WORKSPACE_PATH = '/var/jenkins_home/workspace/cloudflow-pipeline' 
        
        // CRITICAL: Environment variables for DinD service
        DOCKER_HOST = 'tcp://docker:2376'
        DOCKER_CERT_PATH = '/certs/client'
        DOCKER_TLS_VERIFY = '1'
    }

    // 2. Define the services block at the pipeline level (where it is allowed).
    services {
        'docker:dind'
    }

    stages {
        // Stage 1: Checkout Code - Must define the Docker agent
        stage('Checkout Code') {
            agent {
                docker {
                    image 'node:20-bullseye'
                    args '--privileged'
                }
            }
            steps {
                script {
                    echo "Cleaning workspace to resolve file path issues..."
                    cleanWs() 
                    checkout scm 
                }
            }
        }

        // Stage 2: Install & Test
        stage('Install & Test') {
            agent {
                docker { image 'node:20-bullseye' }
            }
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

        // Stage 3: Build & Version Image (Uses DOCKER_HOST service)
        stage('Build & Version Image') {
            agent {
                docker { image 'node:20-bullseye' }
            }
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

        // Stage 4: Compile LaTeX documentation
        stage('Compile LaTeX') {
            agent {
                docker { image 'blang/latex:latest' }
            }
            steps {
                sh 'pdflatex latex.tex || echo "LaTeX failed but continuing build"'
            }
        }

        // Stage 5 & 6: Package and Deploy (Uses DOCKER_HOST service)
        stage('Package Artifact') {
            agent {
                docker { image 'node:20-bullseye' }
            }
            steps {
                sh """
                    echo "Version: ${env.TAG}" > VERSION.txt
                    zip -r deployment-${env.TAG}.zip index.js package.json VERSION.txt latex.pdf
                """
                archiveArtifacts artifacts: "*.zip", fingerprint: true
            }
        }

        stage('Deploy') {
            agent {
                docker { image 'node:20-bullseye' }
            }
            steps {
                echo "Deploying container ${IMAGE}:${env.TAG}"
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