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
        sh '''
          set -eux
          echo "Running tests inside ephemeral node container (clone, start app, wait, test)..."

          docker run --rm node:20-bullseye bash -lc "
            set -eux

            # clone repository
            git clone ${GIT_REPO} /tmp/repo
            cd /tmp/repo

            # install deps (prefer ci)
            npm ci --no-audit --no-fund || npm install --no-audit --no-fund

            # start app in background (try root then app/)
            if [ -f ./index.js ]; then
              echo 'Starting ./index.js'
              node ./index.js > /tmp/app.log 2>&1 &
            elif [ -f ./app/index.js ]; then
              echo 'Starting ./app/index.js'
              node ./app/index.js > /tmp/app.log 2>&1 &
            else
              echo 'No index.js found; cannot start app'
              cat /tmp/app.log || true
              exit 2
            fi

            APP_PID=$!
            echo 'APP PID:' $APP_PID

            # wait for server to accept connections on 127.0.0.1:8080 with retries
            MAX_WAIT=20
            i=0
            while [ \$i -lt \$MAX_WAIT ]; do
              # try to connect using node (no extra tools required)
              node -e '
                const net = require(\"net\");
                const s = net.createConnection({port:8080, host:\"127.0.0.1\"}, () => { console.log(\"open\"); s.end(); process.exit(0) });
                s.on(\"error\", () => process.exit(1));
              ' && break || true
              i=\$((i+1))
              sleep 1
            done

            if [ \$i -ge \$MAX_WAIT ]; then
              echo \"Server did not start within expected time. Last 200 lines of app log:\"
              tail -n 200 /tmp/app.log || true
              kill \$APP_PID || true
              exit 3
            fi

            echo 'Server appears up (after' \$i 'seconds). Running tests...'
            # run test (root vs app/)
            if [ -f ./run_test.js ]; then
              node ./run_test.js
            elif [ -f ./app/run_test.js ]; then
              node ./app/run_test.js
            else
              echo 'run_test.js not found'
              kill \$APP_PID || true
              exit 4
            fi

            TEST_EXIT=\$?
            echo 'Test exit code:' \$TEST_EXIT
            kill \$APP_PID || true
            exit \$TEST_EXIT
          "
        '''
      }
    }

    stage('Build (from git)') {
      steps {
        script {
          def count = sh(script: "git rev-list --count HEAD", returnStdout: true).trim()
          env.TAG = "${VERSION_BASE}.${count}"
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
          set -eux
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
