pipeline {
  agent any

  environment {
    IMAGE = 'cloudflowstocks/web'
    VERSION_BASE = '1.0'
  }

  stages {
    stage('Checkout Code') {
      steps {
        script {
          echo "Cleaning workspace and checking out code..."
          cleanWs()
          checkout scm
        }
      }
    }

    stage('Install & Test') {
      steps {
        // run inside the job workspace; $PWD will be the workspace on the agent
        sh '''
          echo "PWD: $PWD"
          echo "Workspace contents:"
          ls -la

          echo "Starting app container (detached) using workspace bind..."
          APP_ID=$(docker run -d --rm -v "$PWD":/work -w /work node:20-bullseye sh -c "npm install && node index.js")
          echo "App container id: $APP_ID"
          sleep 3

          echo "Running smoke test in a fresh node container (mounting same workspace)..."
          docker run --rm -v "$PWD":/work -w /work node:20-bullseye node run_test.js

          echo "Stopping app container..."
          docker stop $APP_ID || true
        '''
      }
    }

    stage('Build & Version Image') {
      steps {
        script {
          def changelist = sh(script: "git rev-list --count HEAD", returnStdout: true).trim()
          env.TAG = "${VERSION_BASE}.${changelist}"
          echo "Computed image tag: ${env.TAG}"
        }

        // use docker image to run docker build on the host via socket; use \$PWD to let shell expand PWD at runtime
        sh """
          docker run --rm -u 0 \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v "\$PWD":/work -w /work docker:latest \
            sh -c 'docker build -t ${IMAGE}:${env.TAG} .'
        """
      }
    }

    stage('Compile LaTeX') {
      steps {
        // compile LaTeX (continue on failure)
        sh """
          docker run --rm -u 0 -v "\$PWD":/work -w /work blang/latex:latest \
            pdflatex latex.tex || echo 'LaTeX failed but continuing'
        """
      }
    }

    stage('Package Artifact') {
      steps {
        sh """
          echo "Version: ${env.TAG}" > VERSION.txt
          # include main app files and generated latex.pdf if present
          zip -r deployment-${env.TAG}.zip index.js package.json VERSION.txt latex.pdf || true
        """
        archiveArtifacts artifacts: "deployment-${env.TAG}.zip", fingerprint: true
      }
    }

    stage('Deploy') {
      steps {
        echo "Deploying ${IMAGE}:${env.TAG} to host (replacing existing container)"
        // use docker:latest container to run docker commands on host via socket
        sh """
          docker run --rm -u 0 -v /var/run/docker.sock:/var/run/docker.sock docker:latest \
            sh -c "docker stop site-container || true; docker rm site-container || true; docker run -d --name site-container -p 80:8080 ${IMAGE}:${env.TAG}"
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
