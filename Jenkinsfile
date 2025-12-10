pipeline {
  agent any 

  environment {
    // 6. Versioned Deployment Artifact: Base image name
    IMAGE = 'cloudflowstocks/web' 
    VERSION_BASE = '1.0'
    GIT_REPO = 'https://github.com/JustinGaj/ssw590-cloudflow.git'
    GIT_REF  = 'main'
  }

  stages {
    stage('Checkout (host)') {
      steps {
        script {
          // Clear workspace and checkout latest code (Required for Artifact archiving later)
          cleanWs()
          checkout scm
        }
      }
    }

    // 4. Build Visibility & 5. Automated Testing
    stage('Test & Validation (Node Container)') {
      steps {
        sh '''
          echo "Starting Node.js ephemeral container for dependency installation and tests..."
          
          docker run --rm node:20-bullseye bash -lc "
            set -eux

            # Clone the repository inside the temporary container environment
            git clone ${GIT_REPO} /tmp/repo
            cd /tmp/repo

            echo '--- 4. Installing Dependencies ---'
            npm ci --no-audit --no-fund || npm install --no-audit --no-fund

            # Start app in background on loopback interface
            echo '--- Starting Application on 8080 ---'
            node ./index.js > /tmp/app.log 2>&1 &

            APP_PID=\\$! 

            # Wait loop to confirm service is listening
            MAX_WAIT=20
            i=0
            while [ \\$i -lt \\$MAX_WAIT ]; do 
              node -e '
                const net = require(\\"net\\");
                const s = net.createConnection({port:8080, host:\\"127.0.0.1\\"}, () => { console.log(\\"open\\"); s.end(); process.exit(0) });
                s.on(\\"error\\", () => process.exit(1));
              ' && break || true
              i=\\$((\\$i+1)) 
              sleep 1
            done

            if [ \\$i -ge \\$MAX_WAIT ]; then
              echo \\"Server did not start within expected time.\\"
              tail -n 200 /tmp/app.log || true
              kill \\$APP_PID || true 
              exit 3
            fi

            echo '--- 5. Running Automated Tests ---'
            # Execute run_test.js
            node ./run_test.js

            TEST_EXIT=\\$? 
            echo 'Test exit code: ' \\$TEST_EXIT
            
            kill \\$APP_PID || true 
            exit \\$TEST_EXIT
          "
        '''
      }
    }

    // 4. Build Visibility: Building Container Image
    stage('Build Container Image (from Git)') {
      steps {
        script {
          // 6. Versioning: Calculate build number for Major.Minor.Changelist
          def count = sh(script: "git rev-list --count HEAD", returnStdout: true).trim()
          env.TAG = "${VERSION_BASE}.${count}"
          echo "--- 6. Tagging Deployment Artifact: ${IMAGE}:${TAG} ---"
        }
        // Build the Docker image directly from the Git repository URL
        sh "docker run --rm -u 0 -v /var/run/docker.sock:/var/run/docker.sock docker:latest sh -c 'docker build -t ${IMAGE}:${TAG} ${GIT_REPO}#${GIT_REF}'"
      }
    }

    // 4. Build Visibility: Compiling LaTeX documentation
    stage('Compile Documentation (LaTeX Container)') {
      steps {
        sh '''
          set -eux
          rm -f /tmp/latex-${BUILD_ID}.pdf || true
          
          echo '--- 4. Compiling LaTeX Output ---'
          docker run --rm -u 0 -v /tmp:/tmp blang/latex:latest bash -lc "
            rm -rf /tmp/repo || true
            git clone ${GIT_REPO} /tmp/repo &&
            cd /tmp/repo &&
            pdflatex latex.tex && cp -f latex.pdf /tmp/latex-${BUILD_ID}.pdf || true
          "
          
          if [ -f /tmp/latex-${BUILD_ID}.pdf ]; then
            mv /tmp/latex-${BUILD_ID}.pdf ./latex.pdf
            echo 'Documentation artifact saved: latex.pdf'
          else
            echo 'No latex.pdf produced; continuing.'
          fi
        '''
      }
    }
    
    // 4. Build Visibility & 6. Versioned Deployment Artifact: ZIP Package
    stage('Package Artifact (Host)') {
      steps {
        sh '''
          set -eux
          echo '--- 4. Packaging Deployable Artifact ---'
          echo "${TAG}" > VERSION.txt
          # Ensure latex.pdf exists before zipping to prevent error
          if [ ! -f ./latex.pdf ]; then touch ./latex.pdf; fi 
          zip -r deployment-${TAG}.zip index.js package.json VERSION.txt latex.pdf || true
        '''
        archiveArtifacts artifacts: "deployment-${TAG}.zip", fingerprint: true
        echo "Artifact archived: deployment-${env.TAG}.zip"
      }
    }

    stage('Deploy Service (Host Docker)') {
      steps {
        echo "--- Deployment to Host Docker (Exposing 80) ---"
        // Stop and remove old container, then run new image
        sh "docker run --rm -u 0 -v /var/run/docker.sock:/var/run/docker.sock docker:latest sh -c 'docker stop site-container || true; docker rm site-container || true; docker run -d --name site-container -p 80:8080 ${IMAGE}:${TAG}'"
      }
    }
  }

  post {
    success {
      echo "------------------------------------------------"
      echo "✅ DEPLOYMENT SUCCESS: ${IMAGE}:${env.TAG} deployed to port 80."
      echo "------------------------------------------------"
    }
    failure {
      echo "------------------------------------------------"
      echo "🛑 PIPELINE FAILED: Check stage logs."
      echo "------------------------------------------------"
    }
    always {
      echo "Pipeline finished on ${new Date().format('yyyy-MM-dd HH:mm:ss')}"
    }
  }
}