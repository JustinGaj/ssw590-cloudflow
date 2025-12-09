pipeline {
    agent {
        docker {
            image 'node:20-bullseye'
        }
    }

    environment {
        IMAGE = 'cloudflowstocks/web' 
        VERSION_BASE = '1.0'
        // RE-ADDED: Define the absolute path to prevent shell resolution errors
        WORKSPACE_PATH = '/var/jenkins_home/workspace/cloudflow-pipeline' 
    }

    stages {
        // ... (Checkout Code and Install & Test stages are correct and unchanged) ...
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

        // Stage 3: Build the Docker Image and create a Semantic Version
        stage('Build & Version Image') {
            steps {
                script {
                    def changelist = sh(script: "git rev-list --count HEAD", returnStdout: true).trim()
                    env.TAG = "${VERSION_BASE}.${changelist}"
                    echo "Building Version: ${env.TAG}"
                    
                    // CRITICAL FIX: Use the resolved $WORKSPACE_PATH variable instead of \$PWD
                    sh "docker run --rm -u 0 -v /var/run/docker.sock:/var/run/docker.sock -v ${WORKSPACE_PATH}:/work -w /work docker:latest docker build -t ${IMAGE}:${env.TAG} ."
                }
            }
        }

        // Stage 4: Compile LaTeX documentation
        stage('Compile LaTeX') {
            agent {
                docker {
                    image 'blang/latex:latest'
                }
            }
            steps {
                sh "docker run --rm -u 0 -v ${WORKSPACE_PATH}:/work -w /work blang/latex:latest pdflatex latex.tex || echo 'LaTeX failed but continuing build'"
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

        // Stage 6: Deploy to the host
        stage('Deploy') {
            steps {
                echo "Deploying container ${IMAGE}:${env.TAG}"
                // CRITICAL FIX: Use the resolved ${WORKSPACE_PATH} variable instead of \$PWD
                sh """
                    docker run --rm -u 0 -v /var/run/docker.sock:/var/run/docker.sock -v ${WORKSPACE_PATH}:/work docker:latest sh -c "
                        docker stop site-container || true; 
                        docker rm site-container || true; 
                        docker run -d --name site-container -p 80:8080 ${IMAGE}:${env.TAG}
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