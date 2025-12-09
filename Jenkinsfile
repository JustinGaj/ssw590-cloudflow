pipeline {
  agent any

  environment {
    IMAGE = 'cloudflowstocks/web'
    VERSION_BASE = '1.0'
    GIT_REPO = 'https://github.com/JustinGaj/ssw590-cloudflow.git'
    GIT_REF  = 'main'
  }

  stages {
    stage('Checkout (host)') {
      steps {
        script {
          // Keep a local checkout for packaging / provenance (host workspace)
          cleanWs()
          checkout scm
        }
      }
    }

    stage('Test (ephemeral container clone)') {
      steps {
        // clone & test inside ephemeral node container so tests don't depend on workspace mounts
        sh '''
          set -eux
          echo "Running tests inside ephemeral node container (cloning repo)..."
          docker run --rm node:20-bullseye bash -lc "
            git clone ${GIT_REPO} /tmp/repo &&
            cd /tmp/repo &&
            npm ci --no-audit --no-fund || npm install --no-audit --no-fund &&
            node run_test.js
          "
        '''
      }
    }

    stage('Build (from git)') {
      steps {
        script {
          def count = sh(script: "git rev-list --count HEAD", returnStdout: true).trim()
          env.TAG = "${VERSION_BASE}.${count}"
          echo "Computed tag: ${env.TAG}"
        }
        // Build directly from the Git repo (avoids build-context mounts)
        sh '''
          docker run --rm -u 0 -v /var/run/docker.sock:/var/run/docker.sock docker:latest sh -c "
            docker build -t ${IMAGE}:${TAG} ${GIT_REPO}#${GIT_REF}
          "
        '''
      }
    }

    stage('LaTeX (containerized)') {
      steps {
        sh '''
          set -eux
          echo "Compiling LaTeX in container (clone -> compile -> drop to host /tmp)..."
          rm -f /tmp/latex-${BUILD_ID}.pdf || true
          docker run --rm -u 0 -v /tmp:/tmp blang/latex:latest bash -lc "
            rm -rf /tmp/repo || true
            git clone ${GIT_REPO} /tmp/repo &&
            cd /tmp/repo &&
            pdflatex latex.tex && cp -f latex.pdf /tmp/latex-${BUILD_ID}.pdf || true
          "
          if [ -f /tmp/latex-${BUILD_ID}.pdf ]; then
            mv /tmp/latex-${BUILD_ID}.pdf ./latex.pdf
          else
            echo 'No latex.pdf produced; continuing'
          fi
        '''
      }
    }

    stage('Package (host)') {
      steps {
        sh '''
          set -eux
          echo "Packaging deployment artifact from host workspace"
          echo "${TAG}" > VERSION.txt
          zip -r deployment-${TAG}.zip index.js package.json VERSION.txt latex.pdf || true
        '''
        archiveArtifacts artifacts: "deployment-${TAG}.zip", fingerprint: true
      }
    }

    stage('Deploy (host)') {
      steps {
        sh '''
          set -eux
          echo "Deploying ${IMAGE}:${TAG} on host Docker (replace container)"
          docker run --rm -u 0 -v /var/run/docker.sock:/var/run/docker.sock docker:latest sh -c "
            docker stop site-container || true;
            docker rm site-container || true;
            docker run -d --name site-container -p 80:8080 ${IMAGE}:${TAG}
          "
        '''
      }
    }
  }

  post {
    success {
      echo "------------------------------------------------"
      echo "DEMO SUCCESS: ${IMAGE}:${env.TAG} deployed."
      echo "------------------------------------------------"
    }
    failure {
      echo "------------------------------------------------"
      echo "DEMO FAILED: check failing stage logs."
      echo "------------------------------------------------"
    }
    always {
      echo "Pipeline finished on ${new Date().format('yyyy-MM-dd HH:mm:ss')}"
    }
  }
}
