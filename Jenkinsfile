pipeline {
    // CRITICAL FIX: Run the entire pipeline inside a known-good Node environment.
    // This fixes the volume mount and path issues by running npm directly.
    agent {
        docker {
            image 'node:20-slim'
            // Add other tools needed (like Docker) to the container, if required for later stages
            args '-u 0 -v /var/run/docker.sock:/var/run/docker.sock' 
        }
    }

    environment {
        IMAGE = 'cloudflowstocks/web'
        VERSION_BASE = '1.0'
        // WORKSPACE_PATH is no longer needed!
    }

    stages {
        // Stage 1: Checkout is simpler now, as it runs *inside* the Node container.
        stage('Checkout Code') {
            steps {
                script {
                    echo "Cleaning workspace to resolve file path issues..."
                    cleanWs() 
                    // Checkout happens into the Node container's workspace
                    checkout scm 
                }
            }
        }

        // Stage 2: Install dependencies and run automated tests
        stage('Install & Test') {
            steps {
                sh '''
                    echo "Running npm install and tests inside the Node container."
                    
                    # 1. Install dependencies
                    npm install
                
                    # 2. Start the application in the background and capture its PID
                    echo "Starting app in background (PID captured)..."
                    npm start &
                    APP_PID=$!
                    
                    # 3. Wait 3 seconds for the server to spin up and bind to port 8080 (Crucial!)
                    sleep 3
                    
                    # 4. Run the tests (will now connect to the background process)
                    echo "Running automated tests..."
                    npm test
                    TEST_STATUS=$?
                    
                    # 5. Kill the background app process to clean up
                    echo "Stopping background app (PID: $APP_PID)..."
                    kill $APP_PID
                    
                    # 6. Exit with the test status to determine stage success/failure
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
                    
                    // Build still uses the workspace root (.)
                    sh "docker build -t ${IMAGE}:${env.TAG} ."
                }
            }
        }

        // Stage 4: Compile LaTeX documentation (Requirement #4)
        stage('Compile LaTeX') {
            // Use a *different* container for this specific step only
            agent {
                docker {
                    image 'blang/latex:latest'
                }
            }
            steps {
                // Since this agent is the latex container, we run pdflatex directly
                sh 'pdflatex latex.tex || echo "LaTeX failed but continuing build"'
            }
        }

        // Stage 5: Package the deployable artifact (Requirement #4 & #6)
        // Switch back to the Node agent
        stage('Package Artifact') {
            agent { docker { image 'node:20-slim' } }
            steps {
                sh """
                    echo "Version: ${env.TAG}" > VERSION.txt
                    zip -r deployment-${env.TAG}.zip index.js package.json VERSION.txt latex.pdf
                """
                archiveArtifacts artifacts: "*.zip", fingerprint: true
            }
        }

        // Stage 6: Deploy to the host (Requirement #4)
        // Switch back to the Node agent (must have Docker access)
        stage('Deploy') {
            agent { docker { image 'node:20-slim' } }
            steps {
                echo "Deploying container ${IMAGE}:${env.TAG}"
                sh """
                    docker stop site-container || true
                    docker rm site-container || true
                    docker run -d --name site-container -p 80:8080 ${IMAGE}:${env.TAG}
                """
            }
        }
    }

    // Post-build actions remain the same
    post {
        success {
            echo "------------------------------------------------"
            echo "DEMO SUCCESS: Version ${env.TAG} is live! 🎉"
            echo "------------------------------------------------"
        }
        failure {
            echo "------------------------------------------------"
            echo "DEMO FAILED: Check logs. 🛑"
            echo "------------------------------------------------"
        }
    }
}