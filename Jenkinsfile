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

          echo "HOST: PWD = $PWD"
          echo "HOST workspace listing:"
          ls -la

          echo "Starting app container (detached) - try root then app/ paths"
          # start app trying both locations; keep detached
          APP_ID=$(docker run -d --rm -v "$PWD":/work -w /work node:20-bullseye bash -lc '
            npm install --no-audit --no-fund || true
            if [ -f "./index.js" ]; then
              echo "Starting ./index.js"
              node ./index.js &
            elif [ -f "./app/index.js" ]; then
              echo "Starting ./app/index.js"
              node ./app/index.js &
            else
              echo "No index.js found - exiting"
              exit 2
            fi
            sleep 99999
          ')
          echo "App container id: $APP_ID"
          sleep 4

          echo "DEBUG: What the test container sees at /work:"
          docker run --rm -v "$PWD":/work -w /work node:20-bullseye bash -lc 'pwd; ls -la /work; echo "If app exists, list it:"; ls -la /work/app || true'

          echo "Running smoke test (try root then app/ paths)"
          docker run --rm -v "$PWD":/work -w /work node:20-bullseye bash -lc '
            if [ -f "./run_test.js" ]; then
              echo "Running ./run_test.js"; node ./run_test.js; exit $?
            elif [ -f "./app/run_test.js" ]; then
              echo "Running ./app/run_test.js"; node ./app/run_test.js; exit $?
            else
              echo "run_test.js not found in root or app/"; exit 3
            fi
          '

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
