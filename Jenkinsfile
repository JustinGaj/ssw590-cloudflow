stage('Test (ephemeral container run)') {
  steps {
    script {

      // Write test runner into workspace
      writeFile file: 'run_tests.sh', text: '''#!/bin/bash
        set -eux
        echo "Running tests inside ephemeral Node container..."

        cd /workspace

        # Install dependencies
        npm ci --no-audit --no-fund || npm install --no-audit --no-fund

        # Start the app
        echo "Starting index.js..."
        node index.js > /tmp/app.log 2>&1 &
        APP_PID=$!

        # Wait for port 8080
        MAX_WAIT=20
        i=0
        while [ $i -lt $MAX_WAIT ]; do
          node -e '
            const net = require("net");
            const s = net.createConnection({port:8080, host:"127.0.0.1"}, () => { process.exit(0) });
            s.on("error", () => process.exit(1));
          ' && break || true
          i=$((i+1))
          sleep 1
        done

        if [ $i -ge $MAX_WAIT ]; then
          echo "App failed to start"
          tail -n 200 /tmp/app.log || true
          kill $APP_PID || true
          exit 3
        fi

        echo "App is up — running tests..."
        node run_test.js
        TEST_EXIT=$?

        kill $APP_PID || true
        exit $TEST_EXIT
      '''

      sh 'chmod +x run_tests.sh'

      // Run inside clean Node container
      sh '''
        docker run --rm \
          -v $PWD:/workspace \
          node:20-bullseye \
          bash -lc "/workspace/run_tests.sh"
      '''
    }
  }
}
