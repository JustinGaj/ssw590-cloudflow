pipeline {
    agent any 

    stages {
        stage('Step 1: Verify Checkout') {
            steps {
                // This step ensures Jenkins successfully checks out the repository
                sh 'echo "The repository has been checked out successfully!"'
                sh 'ls -F' // List files to prove the workspace contains your code
            }
        }

        stage('Step 2: Basic Shell Command') {
            steps {
                // This step confirms the agent can run a shell command
                script {
                    def now = new Date().format('yyyy-MM-dd HH:mm:ss')
                    echo "Hello, Jenkins! The current time is ${now}"
                }
            }
        }
    }

    post {
        success {
            echo "--- SUCCESS! Pipeline ran end-to-end. ---"
        }
        failure {
            echo "--- FAILURE! Check logs for errors. ---"
        }
        always {
            echo "Pipeline finished."
        }
    }
}