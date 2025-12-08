pipeline {
  agent { dockerfile true}
  stages {
    stage('Checkout') { steps { checkout scm } }

    stage('Install deps (in node container)') {
      steps {
        sh '''
          echo "Running npm ci inside node:20-slim"
          docker run --rm -v "$PWD/app":/work -w /work node:20-slim sh -c "npm ci"
        '''
      }
    }

    stage('Build image') {
      steps {
        script {
          def changeCount = sh(script: "git rev-list --count HEAD", returnStdout: true).trim()
          def base = readFile(env.VERSION_FILE).trim()
          env.TAG = "${base}.${changeCount}"
          sh "docker build -t ${IMAGE}:${TAG} ."
        }
      }
    }

    stage('Run smoke test') {
      steps {
        sh '''
          echo "Starting app container for test"
          docker run -d --rm -p 8080:8080 --name cfstest ${IMAGE}:${TAG}
          sleep 2
          echo "Running smoke test inside node container"
          docker run --rm -v "$PWD":/work -w /work node:20-slim sh -c "node /work/run_test.js"
          docker stop cfstest || true
        '''
      }
    }

    stage('Compile LaTeX') {
      steps {
        sh 'docker run --rm -v "$PWD":/work -w /work blang/latex:latest pdflatex latex.tex || true'
      }
    }

    stage('Package artifact') {
      steps {
        sh """
          mkdir -p out
          cp -r app out
          echo Version:${TAG} > out/VERSION.txt
          zip -r deploy-${TAG}.zip out
        """
        archiveArtifacts artifacts: "deploy-${TAG}.zip", fingerprint: true
      }
    }

    stage('Deploy to host (replace container)') {
      steps {
        sh """
          docker tag ${IMAGE}:${TAG} ${IMAGE}:latest || true
          docker stop cloudflowstocks-site || true
          docker rm cloudflowstocks-site || true
          docker run -d --name cloudflowstocks-site -p 80:8080 ${IMAGE}:${TAG}
        """
      }
    }
  }

  post {
    always { echo "Pipeline finished" }
    success { echo "SUCCESS: ${env.TAG}" }
    failure { echo "FAILED" }
  }
}
