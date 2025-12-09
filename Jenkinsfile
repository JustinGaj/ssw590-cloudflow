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
          cleanWs()
          checkout scm
        }
      }
    }

    stage('Test (ephemeral container clone & run)') {
      steps {
        script {
          writeFile file: 'run_tests.sh', text: '''
            #!/bin/bash
            set -eux

            echo "Running tests inside ephemeral node container..."

            # clone repository
            git clone "$GIT_REPO" /tmp/repo
            cd /tmp/repo

            npm ci --no-audit --no-fund || npm install --no-audit --no-fund

            # Start app
            if [ -f ./index.js ]; then
              node ./index.js > /tmp/app.log 2>&1 &
            elif [ -f ./app/index.js ]; then
              node ./app/index.js > /tmp/app.log 2>&1 &
            else
              echo "No index.js found"
              exit 2
            fi

            APP_PID=$!
            echo "APP PID: $APP_PID"

            # Wait for server on port 8080
            MAX_WAIT=20
            i=0
            while [ $i -lt $MAX_WAIT ]; do
              node -e '
                const net = require("net");
                const s = net.createConnection({port:8080}, () => { console.log("open"); s.end(); process.exit(0) });
                s.on("error", () => process.exit(1));
              ' && break
              i=$((i+1))
              sleep 1
            done

            if [ $i -eq $MAX_WAIT ]; then
              echo "Server never started"
              tail -n 200 /tmp/app.log || true
              kill $APP_PID || true
              exit 3
            fi

            echo "Server up in $i seconds"

            if [ -f ./run_test.js ]; then
              node ./run_test.js
            elif [ -f ./app/run_test.js ]; then
              node ./app/run_test.js
            else
              echo "run_test.js not found"
              kill $APP_PID || true
              exit 4
            fi

            TEST_EXIT=$?
            kill $APP_PID || true
            exit $TEST_EXIT
          '''

          sh 'chmod +x run_tests.sh'

          sh '''
            docker run --rm \
              -v $PWD/run_tests.sh:/run_tests.sh \
              node:20-bullseye \
              bash -lc "/run_tests.sh"
          '''
        }
      }
    }

    stage('Build (from git)') {
      steps {
        script {
          env.TAG = "${VERSION_BASE}." + sh(script: "git rev-list --count HEAD", returnStdout: true).trim()
        }
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
          docker run --rm -u 0 -v /tmp:/tmp blang/latex:latest bash -lc "
            git clone ${GIT_REPO} /tmp/repo &&
            cd /tmp/repo &&
            pdflatex latex.tex &&
            cp latex.pdf /tmp/latex-${BUILD_ID}.pdf
          " || true

          if [ -f /tmp/latex-${BUILD_ID}.pdf ]; then
            mv /tmp/latex-${BUILD_ID}.pdf ./latex.pdf
          fi
        '''
      }
    }

    stage('Package (host)') {
      steps {
        sh '''
          echo "${TAG}" > VERSION.txt
          zip -r deployment-${TAG}.zip index.js package.json VERSION.txt latex.pdf || true
        '''
        archiveArtifacts artifacts: "deployment-${TAG}.zip", fingerprint: true
      }
    }

    stage('Deploy (host)') {
      steps {
        sh '''
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
      echo "SUCCESS"
    }
    failure {
      echo "FAILED"
    }
  }
}
