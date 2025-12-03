pipeline {
  agent any
  environment { IMAGE = 'cloudflowstocks/web' }
  stages {

    // Run npm inside a node container so Jenkins host doesn't need npm installed
    stage('Install (inside node container)') {
      steps {
        sh '''
          echo "Running npm ci inside node:20-slim"
          docker run --rm -v "$PWD/app":/work -w /work node:20-slim sh -c "npm ci"
        '''
      }
    }

    stage('Build') {
      steps {
        script {
          def changeCount = sh(script: "git rev-list --count HEAD", returnStdout: true).trim()
          def base = readFile('VERSION').trim()
          env.TAG = "${base}.${changeCount}"
          sh "docker build -t ${IMAGE}:${TAG} ."
        }
      }
    }

    stage('Test') {
      steps {
        sh "docker run -d --rm -p 8080:8080 --name cfstest ${IMAGE}:${TAG}"
        sh 'sleep 2'
        sh 'node run_test.js'    // this runs on Jenkins host - it accesses localhost:8080
        sh 'docker stop cfstest || true'
      }
    }

    stage('LaTeX (inside container)') {
      steps {
        sh 'docker run --rm -v "$PWD":/work -w /work blang/latex:latest pdflatex latex.tex || true'
      }
    }

    stage('Package') {
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
  }

  post {
    always { echo 'Done' }
    success { echo "SUCCESS: ${env.TAG}" }
    failure { echo 'FAILED' }
  }
}
