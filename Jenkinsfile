pipeline {
    agent any

    environment {
        IMAGE = 'cloudflowstocks/web'
        VERSION_BASE = '1.0'
    }

    stages {
        stages {
        stage('Declarative: Checkout SCM') {
            steps {
                // Keep this one simple, it's just to get the Jenkinsfile
                checkout scm
            }
        }

        stage('Checkout') {
            steps {
                script {
                    // Use a clean checkout to remove any old files or sub-directories
                    // that might be hiding the true files.
                    cleanWs() 
                    
                    // Force a full checkout again
                    checkout([$class: 'GitSCM', 
                        branches: [[name: '*/main']], 
                        doGenerateSubmoduleConfigurations: false, 
                        extensions: [], 
                        submoduleCfg: [], 
                        userRemoteConfigs: [[url: 'https://github.com/JustinGaj/ssw590-cloudflow.git']]])
                }
            }
        }
        // ... rest of the stages follow ...

      stage('Install & Test') {
          steps {
              sh '''
                  echo "Running tests in node container"
                  
                  # Use chmod for safety (runs on host)
                  chmod -R a+rwx .
                  
                  # FINAL ATTEMPT: Hardcode the absolute workspace path
                  # This bypasses any shell variable ($PWD) or path resolution issues.
                  docker run --rm -u 0 -v /var/jenkins_home/workspace/cloudflow-pipeline:/work -w /work node:20-slim sh -c 'npm install && npm test'
              '''
          }
      }

      stage('Build & Version Image') {
          steps {
              script {
                  def changelist = sh(script: "git rev-list --count HEAD", returnStdout: true).trim()
                  env.TAG = "${VERSION_BASE}.${changelist}"
                  echo "Building Version: ${env.TAG}"
                  // Build context should be the current directory (.)
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
                # Package files from the root context
                zip -r deployment-${env.TAG}.zip index.js package.json VERSION.txt latex.pdf
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