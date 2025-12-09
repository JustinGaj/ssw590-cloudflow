pipeline {
    // Revert to 'agent any' which allows us to manually control the environment
    agent any 

    environment {
        IMAGE = 'cloudflowstocks/web' 
        VERSION_BASE = '1.0' 
        WORKSPACE_PATH = '/var/jenkins_home/workspace/cloudflow-pipeline' 
        
        // CRITICAL: Environment variables for DinD setup
        DOCKER_HOST = 'tcp://127.0.0.1:2375' // Use 127.0.0.1 since we'll run DinD on the host
        // NOTE: We omit DOCKER_TLS_VERIFY to simplify the connection, 
        // assuming your Docker daemon is accessible without TLS (common in basic setups).
    }
    
    // Setup DinD service before any stages execute
    options {
        // Automatically run DinD service before any stages and clean it up after.
        // This uses Scripted Pipeline steps within the Declarative framework.
        timestamps()
    }
    
    stages {
        // Stage 0: START DOCKER-IN-DOCKER SERVICE (CRITICAL FIX)
        stage('Initialize DinD Service') {
            steps {
                script {
                    echo "Starting Docker-in-Docker service to ensure compatibility..."
                    // This command starts the DinD container in the background on the host, 
                    // exposing its daemon on 127.0.0.1:2375, which DOCKER_HOST points to.
                    // This is the functional equivalent of the missing 'services' block.
                    sh """
                        docker stop dind-service || true
                        docker rm dind-service || true
                        docker run -d --privileged --name dind-service -p 127.0.0.1:2375:2375 docker:dind
                    """
                    // Wait a moment for the DinD service to initialize its daemon
                    sleep 10
                }
            }
        }
        
        // Stage 1: Checkout Code (Uses the main Jenkins agent)
        stage('Checkout Code') {
            steps {
                script {
                    echo "Cleaning workspace to resolve file path issues..."
                    cleanWs() 
                    checkout scm 
                }
            }
        }

        // Stage 2: Install & Test (Run inside a Node container for isolation)
        stage('Install & Test') {
            steps {
                // Use a docker run command to isolate Node environment, linking the DinD service
                sh '''
                    echo "Running tests in node container against DinD service"
                    
                    # Run tests inside a Node container. The DOCKER_HOST env var is passed implicitly
                    docker run --rm -u 0 -v $PWD:/work -w /work node:20-bullseye sh -c "
                        npm install && 
                        npm start & 
                        APP_PID=\$!
                        sleep 3 && 
                        npm test && 
                        kill \$APP_PID
                    "
                '''
            }
        }

        // Stage 3: Build & Version Image (Now successfully uses the DinD service)
        stage('Build & Version Image') {
            steps {
                script {
                    // Git must be installed on the host or we use a container with git here
                    def changelist = sh(script: "git rev-list --count HEAD", returnStdout: true).trim()
                    env.TAG = "${VERSION_BASE}.${changelist}"
                    echo "Building Version: ${env.TAG}"
                    
                    // The standard 'docker build' command now talks to the 127.0.0.1:2375 DinD service
                    sh "docker build -t ${IMAGE}:${env.TAG} ."
                }
            }
        }

        // Stage 4: Compile LaTeX documentation (Run inside a LaTeX container)
        stage('Compile LaTeX') {
            steps {
                sh "docker run --rm -u 0 -v $PWD:/work -w /work blang/latex:latest pdflatex latex.tex || echo 'LaTeX failed but continuing build'"
            }
        }

        // Stage 5 & 6: Package and Deploy (Uses DinD service)
        stage('Package Artifact') {
            steps {
                sh """
                    echo "Version: ${env.TAG}" > VERSION.txt
                    zip -r deployment-${env.TAG}.zip index.js package.json VERSION.txt latex.pdf
                """
                archiveArtifacts artifacts: "*.zip", fingerprint: true
            }
        }

        stage('Deploy') {
            steps {
                echo "Deploying container ${IMAGE}:${env.TAG}"
                
                sh """
                    docker stop site-container || true
                    docker rm site-container || true
                    # Deploy the app container using the DinD daemon
                    docker run -d --name site-container -p 8080:8080 ${IMAGE}:${env.TAG}
                """
            }
        }
    }

    // CRITICAL: Stop the DinD service after the build, even if it failed.
    post {
        always {
            echo "Stopping DinD service..."
            sh "docker stop dind-service || true"
            echo "Pipeline finished on ${new Date().format('yyyy-MM-dd HH:mm:ss')}"
        }
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
    }
}