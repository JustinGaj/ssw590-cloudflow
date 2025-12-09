pipeline {
    // CRITICAL FIX: Set the Docker agent for the whole pipeline.
    // We use a full Node image that contains Git.
    agent {
        docker {
            image 'node:20-bullseye'
            // We REMOVE the socket mount here. It will be added explicitly 
            // only for the stages that need to talk to the Docker host (Build/Deploy).
        }
    }

    environment {
        // Your Docker Hub repo and image name
        IMAGE = 'cloudflowstocks/web' 
        VERSION_BASE = '1.0' // Major.Minor base
    }

    stages {
        // Stage 1: Clean and get the code (CRITICAL FIX)
        stage('Checkout Code') {
            steps {
                script {
                    echo "Cleaning workspace to resolve file path issues..."
                    cleanWs() 
                    checkout scm 
                }
            }
        }

        // Stage 2: Install dependencies and run automated tests
        stage('Install & Test') {
            steps {
                // Commands run directly inside the 'node:20-bullseye' agent
                sh '''
                    echo "Running npm install and tests inside the Node container."
                    
                    # 1. Install dependencies
                    npm install
                
                    # 2. Start the application in the background
                    echo "Starting app in background..."
                    npm start &
                    APP_PID=$!
                    
                    # 3. Wait for the server to spin up
                    sleep 3
                    
                    # 4. Run the tests (Now successful!)
                    echo "Running automated tests..."
                    npm test
                    TEST_STATUS=$?
                    
                    # 5. Kill the background app process
                    kill $APP_PID
                    
                    # 6. Exit with the test status
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
                    
                    // FIX: Run 'docker build' inside the separate, compatible 'docker:latest' container
                    // This bypasses the GLIBC version mismatch error.
                    sh "docker run --rm -u 0 -v /var/run/docker.sock:/var/run/docker.sock -v \$PWD:/work -w /work docker:latest docker build -t ${IMAGE}:${env.TAG} ."
                }
            }
        }

        // Stage 4: Compile LaTeX documentation
        stage('Compile LaTeX') {
            // Temporarily switch the agent to the LaTeX container for this step only
            agent {
                docker {
                    image 'blang/latex:latest'
                }
            }
            steps {
                // Command runs directly inside the 'blang/latex:latest' container
                sh 'pdflatex latex.tex || echo "LaTeX failed but continuing build"'
            }
        }

        // Stage 5: Package the deployable artifact
        // This stage runs back in the 'node:20-bullseye' agent
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

        // Stage 6: Deploy to the host
        stage('Deploy') {
            steps {
                echo "Deploying container ${IMAGE}:${env.TAG}"
                // FIX: Run deployment commands inside the compatible 'docker:latest' container
                sh """
                    docker run --rm -u 0 -v /var/run/docker.sock:/var/run/docker.sock -v \$PWD:/work docker:latest sh -c "
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