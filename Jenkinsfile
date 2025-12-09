pipeline {
  agent any

  environment {
    IMAGE = 'cloudflowstocks/web'
    VERSION_BASE = '1.0'
  }

  stages {
    stage('Checkout') {
      steps {
        script {
          echo "Clean workspace and checkout"
          cleanWs()
          checkout scm
        }
      }
    }

    stage('Install & Test') {
      steps {
        sh '''
          set -eux

          echo "PWD: $PWD"
          echo "Workspace listing:"
          ls -la

          # Ensure required files exist in root
          if [ ! -f "./index.js" ]; then echo "ERROR: index.js not found in repo root"; exit 1; fi
          if [ ! -f "./run_test.js" ]; then echo "ERROR: run_test.js not found in repo root"; exit 1; fi

          echo "Installing deps and starting app (detached)..."
          APP_ID=$(docker run -d --rm -v "$PWD":/work -w /work node:20-bullseye bash -lc "npm install --no-audit --no-fund && node index.js")
          echo "App container id: $APP_ID"
          sleep 4

          echo "Verify container workspace:"
          docker run --rm -v "$PWD":/work -w /work node:20-bullseye bash -lc "pwd; ls -la /work"

          echo "Run smoke test:"
          docker run --rm -v "$PWD":/work -w /work node:20-bullseye bash -lc "node run_test.js"

          echo "Stopping app container..."
          docker stop $APP_ID || true
        '''
      }
    }

    stage('Build & Tag') {
      steps {
        script {
          def count = sh(script: "git rev-list --count HEAD", returnStdout: true).trim()
          env.TAG = "${VERSION_BASE}.${count}"
          echo "Computed tag: ${env.TAG}"
        }
        sh '''
          docker run --rm -u 0 \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v "$PWD":/work -w /work docker:latest \
            sh -c "docker build -t ${IMAGE}:${TAG} ."
        '''
      }
    }

    stage('LaTeX') {
      steps {
        sh '''
          docker run --rm -u 0 -v "$PWD":/work -w /work blang/latex:latest \
            pdflatex latex.tex || echo "LaTeX failed; continuing"
        '''
      }
    }

    stage('Package') {
      steps {
        sh '''
          echo "${TAG}" > VERSION.txt
          zip -r deployment-${TAG}.zip index.js package.json VERSION.txt latex.pdf || true
        '''
        archiveArtifacts artifacts: "deployment-${TAG}.zip", fingerprint: true
      }
    }

    stage('Deploy') {
      steps {
        echo "Deploying ${IMAGE}:${TAG}"
        sh '''
          docker run --rm -u 0 -v /var/run/docker.sock:/var/run/docker.sock docker:latest \
            sh -c "docker stop site-container || true; docker rm site-container || true; docker run -d --name site-container -p 80:8080 ${IMAGE}:${TAG}"
        '''
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
