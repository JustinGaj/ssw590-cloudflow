pipeline {
    agent none

    stages {
        stage('Test (ephemeral container run)') {
            agent {
                docker {
                    image 'node:18'
                    args '-u root:root'
                }
            }

            steps {
                sh 'node -v'
                sh 'npm install'
                sh 'node run_test.js'
            }
        }
    }
}
