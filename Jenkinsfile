pipeline {
    // Rely on the standard Jenkins executor (agent any) for flexibility
    agent any 

    environment {
        IMAGE = 'cloudflowstocks/web' 
        VERSION_BASE = '1.0' 
        // CRITICAL: Define the absolute path. This guarantees correct volume mounting (Fixes ENOENT).
        WORKSPACE_PATH = '/var/jenkins_home/workspace/cloudflow-pipeline' 
        // DOCKER_HOST variables are intentionally removed to force use of the host's /var/run/docker.sock
    }
    
    stages {
        // Stage 1: Checkout Code
        stage('Checkout Code') {
            steps {
                script {
                    echo "Cleaning workspace to resolve file path issues..."
                    cleanWs() 
                    checkout scm 
                }
            }
        }

        // Stage 2: Install & Test 🧪
        stage('Install & Test') {
            steps {
                // CRITICAL FIX: Escaping the inner shell command quotes and variables (\", \\$!) 
                // to prevent Groovy from corrupting the multi-line sh -c string.
                sh """
                    echo "Running tests in node container."
                    
                    docker run --rm -v ${WORKSPACE_PATH}:/work -w /work node:20-bullseye sh -c \\"
                        npm install && 
                        npm start & 
                        APP_PID=\\\$!
                        sleep 3 && 
                        npm test && 
                        kill \\\$APP_PID
                    \\"
                """
            }
        }

        // Stage 3: Build & Version Image 🏗️
        stage('Build & Version Image') {
            steps {
                script {
                    def changelist = sh(script: "git rev-list --count HEAD", returnStdout: true).trim()
                    env.TAG = "${VERSION_BASE}.${changelist}"
                    echo "Building Version: ${env.TAG}"
                    
                    // CRITICAL FIX: Wrapper command to bypass GLIBC issues and run 'docker build'
                    sh "docker run --rm -u 0 -v /var/run/docker.sock:/var/run/docker.sock -v ${WORKSPACE_PATH}:/work -w /work docker:latest docker build -t ${IMAGE}:${env.TAG} ."
                }
            }
        }

        // Stage 4: Compile LaTeX documentation
        stage('Compile LaTeX') {
            steps {
                // Run LaTeX compilation inside a container, mounting the absolute workspace
                sh "docker run --rm -u 0 -v ${WORKSPACE_PATH}:/work -w /work blang/latex:latest pdflatex latex.tex || echo 'LaTeX failed but continuing build'"
            }
        }

        // Stage 5: Package Artifact
        stage('Package Artifact') {
            steps {
                sh """
                    echo "Version: ${env.TAG}" > VERSION.txt
                    zip -r deployment-${env.TAG}.zip index.js package.json VERSION.txt latex.pdf
                """
                archiveArtifacts artifacts: "*.zip", fingerprint: true
            }
        }

        // Stage 6: Deploy 🚢
        stage('Deploy') {
            steps {
                echo "Deploying container ${IMAGE}:${env.TAG}"
                
                // Deploy command, run inside the compatible docker:latest container
                sh """
                    docker run --rm -u 0 -v /var/run/docker.sock:/var/run/docker.sock docker:latest sh -c "
                        docker stop site-container || true; 
                        docker rm site-container || true; 
                        docker run -d --name site-container -p 8080:8080 ${IMAGE}:${env.TAG}
                    "
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