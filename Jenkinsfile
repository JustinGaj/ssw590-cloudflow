pipeline {
    agent any

    environment {
        // Your Docker Hub repo and image name
        IMAGE = 'cloudflowstocks/web' 
        VERSION_BASE = '1.0' // Major.Minor base
        // Hardcoded path to avoid shell variable issues (FINAL FIX)
        WORKSPACE_PATH = '/var/jenkins_home/workspace/cloudflow-pipeline'
    }

    stages {
        // Stage 1: Get the Jenkinsfile itself
        stage('Declarative: Checkout SCM') {
            steps { checkout scm }
        }

        // Stage 2: Clean and get the rest of the code (CRITICAL FIX)
        stage('Checkout Code') {
            steps {
                script {
                    echo "Cleaning workspace to resolve file path issues..."
                    // CRITICAL FIX: Ensures no stale files are left, guaranteeing package.json is in root
                    cleanWs() 
                    
                    // Explicit, full checkout (using default SCM settings)
                    checkout scm 
                }
            }
        }

        // Stage 3: Install dependencies and run automated tests (CRITICAL FIXES HERE)
        stage('Install & Test') {
            steps {
                sh '''
                    echo "Running tests in node container"
                    
                    # Ensure file permissions are open on the host before mounting (Safety)
                    chmod -R a+rwx .
                    
                    # FINAL FIX: Use -u 0 (root) and single quotes for correct command parsing
                    docker run --rm -u 0 -v $WORKSPACE_PATH:/work -w /work node:20-slim sh -c 'npm install && npm test'
                '''
            }
        }

        // Stage 4: Build the Docker Image and create a Semantic Version
        stage('Build & Version Image') {
            steps {
                script {
                    // Requirement #6: Calculate semantic version (major.minor.changelist)
                    def changelist = sh(script: "git rev-list --count HEAD", returnStdout: true).trim()
                    env.TAG = "${VERSION_BASE}.${changelist}"
                    echo "Building Version: ${env.TAG}"
                    
                    // Build context is the current directory (.)
                    sh "docker build -t ${IMAGE}:${env.TAG} ."
                }
            }
        }

        // Stage 5: Compile LaTeX documentation (Requirement #4)
        stage('Compile LaTeX') {
            steps {
                 // Use a separate container to compile the LaTeX file
                sh "docker run --rm -u 0 -v $WORKSPACE_PATH:/work -w /work blang/latex:latest pdflatex latex.tex || echo 'LaTeX failed but continuing build'"
            }
        }

        // Stage 6: Package the deployable artifact (Requirement #4 & #6)
        stage('Package Artifact') {
            steps {
                sh """
                    echo "Version: ${env.TAG}" > VERSION.txt
                    # Package the source code, version, and generated PDF
                    zip -r deployment-${env.TAG}.zip index.js package.json VERSION.txt latex.pdf
                """
                archiveArtifacts artifacts: "*.zip", fingerprint: true
            }
        }

        // Stage 7: Deploy to the host (Requirement #4)
        stage('Deploy') {
            steps {
                echo "Deploying container ${IMAGE}:${env.TAG}"
                sh """
                    docker stop site-container || true
                    docker rm site-container || true
                    # Deploy the newly built, versioned image
                    docker run -d --name site-container -p 80:8080 ${IMAGE}:${env.TAG}
                """
            }
        }
    }

    // Post-build actions for clear pass/fail results (Requirement #5 & #9)
    post {
        success {
            echo "------------------------------------------------"
            echo "DEMO SUCCESS: Version ${env.TAG} is live! 🎉"
            echo "------------------------------------------------"
        }
        failure {
            echo "------------------------------------------------"
            echo "DEMO FAILED: Check logs for 'Install & Test' stage. 🛑"
            echo "------------------------------------------------"
        }
        always {
            echo "Pipeline finished on ${new Date().format('yyyy-MM-dd HH:mm:ss')}"
        }
    }
}