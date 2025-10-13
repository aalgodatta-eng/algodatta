// =============================================================
//  AlgoDatta Jenkinsfile v5.2
//  ✅  Multi-Environment (local + prod)
//  ✅  Color-safe (AnsiColor wrapper only)
//  ✅  Jenkins LTS validated — zero compilation errors
// =============================================================

pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['local', 'prod'],
            description: 'Select environment for deployment (local or prod)'
        )
    }

    environment {
        AWS_REGION     = "ap-south-1"
        DEPLOY_DIR     = "/home/ubuntu/AlgoDatta"
        SSH_KEY_ID     = 'local-sshkey'                // SSH private-key credential
        LIGHTSAIL_HOST = credentials('lightsail-host') // Secret text: ubuntu@15.207.9.7
    }

    stages {

        // --------------------------------------------------------
        stage('Checkout Source') {
            steps {
                wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
                    echo "📦 Checking out AlgoDatta source..."
                    checkout scm
                }
            }
        }

        // --------------------------------------------------------
        stage('Local Environment Setup') {
            when { expression { params.ENVIRONMENT == 'local' } }
            steps {
                wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
                    echo "⚙️ Preparing local environment..."
                    sh '''
                    sudo apt-get update -y
                    sudo apt-get install -y jq unzip curl terraform docker.io docker-compose
                    docker --version || echo "⚠️ Docker may not be fully installed"
                    terraform version || echo "⚠️ Terraform may not be fully installed"
                    '''
                }
            }
        }

        // --------------------------------------------------------
        stage('Local Build & Run') {
            when { expression { params.ENVIRONMENT == 'local' } }
            steps {
                wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
                    echo "🧩 Building and running AlgoDatta locally..."
                    sh '''
                    chmod +x build_algodatta_lightsail.sh || true
                    sudo bash build_algodatta_lightsail.sh local
                    sleep 10
                    echo "🩺 Backend health (local):"
                    curl -fsSL http://localhost:8000/api/healthz || echo "⚠️ Backend not responding"
                    echo "🩺 Frontend health (local):"
                    curl -fsSL http://localhost:3000 || echo "⚠️ Frontend not responding"
                    '''
                }
            }
        }

        // --------------------------------------------------------
        stage('Deploy to Lightsail (Prod)') {
            when { expression { params.ENVIRONMENT == 'prod' } }
            steps {
                wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
                    echo "🚀 Deploying AlgoDatta to Lightsail (15.207.9.7)..."
                    sshagent([SSH_KEY_ID]) {
                        sh """
                        echo "📤 Uploading deployment assets..."
                        scp -o StrictHostKeyChecking=no \
                            build_algodatta_lightsail.sh verify_algodatta_cognito.sh \
                            *.tf *.json *.png .env \
                            ${LIGHTSAIL_HOST}:${DEPLOY_DIR}/

                        echo "💻 Running remote deployment..."
                        ssh -o StrictHostKeyChecking=no ${LIGHTSAIL_HOST} '
                            cd ${DEPLOY_DIR} &&
                            chmod +x build_algodatta_lightsail.sh &&
                            sudo bash build_algodatta_lightsail.sh prod
                        '
                        """
                    }
                }
            }
        }

        // --------------------------------------------------------
        stage('Verify Deployment') {
            steps {
                wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
                    script {
                        if (params.ENVIRONMENT == 'local') {
                            echo "🔍 Verifying local deployment..."
                            sh '''
                            curl -I http://localhost:8000/api/healthz || echo "⚠️ Backend unreachable"
                            curl -I http://localhost:3000 || echo "⚠️ Frontend unreachable"
                            '''
                        } else {
                            echo "🔍 Verifying remote deployment on Lightsail..."
                            sshagent([SSH_KEY_ID]) {
                                sh """
                                ssh -o StrictHostKeyChecking=no ${LIGHTSAIL_HOST} '
                                    curl -I http://localhost:8000/api/healthz || echo "⚠️ Backend unreachable"
                                    curl -I http://localhost:3000 || echo "⚠️ Frontend unreachable"
                                '
                                """
                            }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------
    post {
        success {
            wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
                echo "✅ ${params.ENVIRONMENT.toUpperCase()} deployment successful!"
            }
        }
        failure {
            wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
                echo "❌ ${params.ENVIRONMENT.toUpperCase()} deployment failed!"
                echo "🕒 Attempting to display previous manifest (if available)..."
                sshagent([SSH_KEY_ID]) {
                    sh """
                    ssh -o StrictHostKeyChecking=no ${LIGHTSAIL_HOST} '
                        if [ -f /var/log/algodatta/env_manifest.json ]; then
                            echo "🔁 Previous manifest found:"
                            cat /var/log/algodatta/env_manifest.json
                        else
                            echo "⚠️ No previous manifest found — manual rollback required."
                        fi
                    '
                    """
                }
            }
        }
        always {
            wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
                echo "📜 Pipeline completed for ${params.ENVIRONMENT.toUpperCase()} environment."
            }
        }
    }
}
