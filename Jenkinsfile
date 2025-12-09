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
        // Use a compact, robust shell which auto-detects file locations and runs tests
        sh '''
          echo "=== PWD and workspace listing ==="
          echo "PWD: $PWD"
          ls -la

          # Detect where index.js and run_test.js are
          if [ -f "$PWD/run_test.js" ]; then
            TEST_FILE="./run_test.js"
          elif [ -f "$PWD/app/run_test.js" ]; then
            TEST_FILE="./app/run_test.js"
          else
            echo "ERROR: run_test.js not found in root or app/"
            exit 1
          fi

          if [ -f "$PWD/index.js" ]; then
            START_FILE="./index.js"
          elif [ -f "$PWD/app/index.js" ]; then
            START_FILE="./app/index.js"
          else
            echo "ERROR: index.js not found in root or app/"
            exit 1
          fi

          echo "Detected START_FILE=$START_FILE and TEST_FILE=$TEST_FILE"

          echo "Starting app container (detached) using workspace bind..."
          # install deps and start the app inside the container; keep it detached
          APP_ID=$(docker run -d --rm -v "$PWD":/work -w /work node:20-bullseye \
            bash -lc "npm install --no-audit --no-fund && node $START_FILE")
          echo "App container id: $APP_ID"
          sleep 4

          echo "Verify container sees files (inside throwaway container):"
          docker run --rm -v "$PWD":/work -w /work node:20-bullseye \
            bash -lc "echo 'Inside test container PWD:' && pwd && echo 'Listing /work:' && ls -la /work"

          echo "Running smoke test: node $TEST_FILE"
          docker run --rm -v "$PWD":/work -w /work node:20-bullseye \
            bash -lc "node $TEST_FILE"

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
        // Build using docker image to execute docker CLI against host socket
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
            pdflatex latex.tex || echo "LaTeX step failed; continuing"
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
