node {
    stage('Checkout') {
        checkout scm
        echo "Repo checked out"
    }

    stage('Set Version') {
        script {
            def versionContent = readFile('version').trim()
            // example: 1.0.245
            env.APP_VERSION = versionContent
            echo "Version set to: ${env.APP_VERSION}"
        }
    }

    stage('Build LaTeX Document') {
        echo "Compiling LaTeX..."
        sh """
            sudo apt-get update
            sudo apt-get install -y texlive texlive-latex-extra
            pdflatex latex.tex
        """
        archiveArtifacts artifacts: 'latex.pdf', allowEmptyArchive: true
    }

    stage('Install Dependencies') {
        echo "Installing Node dependencies"
        sh 'npm install'
    }

    stage('Run Tests') {
        echo "Running automated tests"
        sh 'node run_test.js'
    }

    stage('Build Package') {
        echo "Packaging deployment artifact"

        sh """
            mkdir -p build
            cp -r index.js package.json package-lock.json latex.pdf build/
            zip -r artifact-${APP_VERSION}.zip build/
        """

        archiveArtifacts artifacts: "artifact-${APP_VERSION}.zip"
    }

    stage('Summary') {
        echo "Build completed successfully"
        echo "Artifact version: ${env.APP_VERSION}"
    }
}
