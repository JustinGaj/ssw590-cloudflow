pipeline {
    agent any

    environment {
        IMAGE = 'cloudflowstocks/web'
        VERSION_BASE = '1.0'
    }

    stages {
        stage('Checkout') { 
            steps { checkout scm } 
        }

        stage('Install & Test') {
            steps {
                echo "Running tests in node container"
                // Mounting $PWD to /work ensures package-lock.json is found in the root
                sh 'docker run --rm -v "$PWD":/work -w /work node:20-slim sh -c "npm install && npm test"'
            }
        }

        stage('Build & Version Image') {
            steps {
                script {
                    def changelist = sh(script: "git rev-list --count HEAD", returnStdout: true).trim()
                    env.TAG = "${VERSION_BASE}.${changelist}"
                    echo "Building Version: ${env.TAG}"
                    sh "docker build -t ${IMAGE}:${env.TAG} ."
                }
            }
        }

        stage('Compile LaTeX') {
            steps {
                sh 'docker run --rm -v "$PWD":/work -w /work blang/latex:latest pdflatex latex.tex || echo "LaTeX failed but continuing build"'
            }
        }

        stage('Package Artifact') {
            steps {
                sh """
                    echo "Version: ${env.TAG}" > VERSION.txt
                    zip -r deployment-${env.TAG}.zip index.js package.json VERSION.txt
                """
                archiveArtifacts artifacts: "*.zip", fingerprint: true
            }
        }

        stage('Deploy') {
            steps {
                sh """
                    docker stop site-container || true
                    docker rm site-container || true
                    docker run -d --name site-container -p 80:8080 ${IMAGE}:${env.TAG}
                """
            }
        }
    }

    // THIS SECTION SUMMARIZES FOR YOUR DEMO
    post {
        success {
            echo "------------------------------------------------"
            echo "DEMO SUCCESS: Version ${env.TAG} is live!"
            echo "------------------------------------------------"
        }
        failure {
            echo "------------------------------------------------"
            echo "DEMO FAILED: Check the test logs above."
            echo "------------------------------------------------"
        }
        always {
            echo "Pipeline finished on ${new Date().format('yyyy-MM-dd HH:mm:ss')}"
            // Optional: Clean up images older than the current one to save disk space on droplet
            // sh 'docker image prune -f'
        }
    }
}