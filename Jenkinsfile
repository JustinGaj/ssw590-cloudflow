pipeline {
    // Rely on the standard Jenkins executor and its privileges (after fixing permissions on host)
    agent any 

    environment {
        IMAGE = 'cloudflowstocks/web' 
        VERSION_BASE = '1.0' 
        WORKSPACE_PATH = '/var/jenkins_home/workspace/cloudflow-pipeline' 
        // DOCKER_HOST variables are REMOVED to force use of the host's /var/run/docker.sock
    }
    
    stages {
        // We REMOVE the Initialize DinD Service Stage

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
                // Run tests inside a Node container, mounting the host's workspace
                sh '''
                    echo "Running tests in node container."
                    
                    docker run --rm -v $PWD:/work -w /work node:20-bullseye sh -c "
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

        // Stage 3: Build & Version Image (Now successfully talks to host via socket)
        stage('Build & Version Image') {
            steps {
                script {
                    def changelist = sh(script: "git rev-list --count HEAD", returnStdout: true).trim()
                    env.TAG = "${VERSION_BASE}.${changelist}"
                    echo "Building Version: ${env.TAG}"
                    
                    // CRITICAL: The build command MUST be run inside a Docker-in-Docker compatible container.
                    // We must revert to the only compatible method that worked previously:
                    sh "docker run --rm -u 0 -v /var/run/docker.sock:/var/run/docker.sock -v ${WORKSPACE_PATH}:/work -w /work docker:latest docker build -t ${IMAGE}:${env.TAG} ."
                }
            }
        }

        // Stage 4: Compile LaTeX documentation (Run inside a LaTeX container)
        stage('Compile LaTeX') {
            steps {
                sh "docker run --rm -u 0 -v $PWD:/work -w /work blang/latex:latest pdflatex latex.tex || echo 'LaTeX failed but continuing build'"
            }
        }

        // Stage 5 & 6: Package and Deploy
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