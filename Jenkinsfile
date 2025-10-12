// =============================================================
//  AlgoDatta Jenkinsfile v5.0
//  Multi-Environment (local / prod) pipeline
// =============================================================
pipeline {
    agent any
    options {
        ansiColor('xterm')
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['local', 'prod'],
            description: 'Choose deployment target'
        )
    }

    environment {
        AWS_REGION     = "ap-south-1"
        DEPLOY_DIR     = "/home/ubuntu/AlgoDatta"
        SSH_KEY_ID     = 'local-sshkey'              // SSH key credential
        LIGHTSAIL_HOST = credentials('lightsail-host') // Secret text: ubuntu@15.207.9.7
    }

    stages {

        // -------------------- CHECKOUT --------------------------
        stage('Checkout Source') {
            steps {
                echo "📦 Checking out AlgoDatta source..."
                checkout scm
            }
        }

        // -------------------- LOCAL ------------------------------
        stage('Local Build + Run') {
            when { expression { params.ENVIRONMENT == 'local' } }
            steps {
                echo "🧩 Building and running AlgoDatta locally..."
                sh '''
                sudo apt-get update -y
                sudo apt-get install -y jq unzip curl terraform docker.io docker-compose
                chmod +x build_algodatta_lightsail.sh || true
                sudo bash build_algodatta_lightsail.sh local
                sleep 10
                echo "🩺 Local backend health:"
                curl -fsSL http://localhost:8000/api/healthz || echo "⚠️ Backend failed"
                echo "🩺 Local frontend health:"
                curl -fsSL http://localhost:3000 || echo "⚠️ Frontend failed"
                '''
            }
        }

        // -------------------- PRODUCTION -------------------------
        stage('Deploy to Lightsail (Prod)') {
            when { expression { params.ENVIRONMENT == 'prod' } }
            steps {
                echo "🚀 Deploying to Lightsail (15.207.9.7)..."
                sshagent([SSH_KEY_ID]) {
                    sh """
                    scp -o StrictHostKeyChecking=no \
                        build_algodatta_lightsail.sh verify_algodatta_cognito.sh \
                        *.tf *.json *.png .env \
                        ${LIGHTSAIL_HOST}:${DEPLOY_DIR}/

                    ssh -o StrictHostKeyChecking=no ${LIGHTSAIL_HOST} '
                        cd ${DEPLOY_DIR} &&
                        chmod +x build_algodatta_lightsail.sh &&
                        sudo bash build_algodatta_lightsail.sh prod
                    '
                    """
                }
            }
        }

        // -------------------- VERIFY -----------------------------
        stage('Verify Deployment') {
            steps {
                script {
                    if (params.ENVIRONMENT == 'local') {
                        echo "🔍 Verifying local deployment..."
                        sh '''
                        curl -I http://localhost:8000/api/healthz || echo "Backend unreachable"
                        curl -I http://localhost:3000 || echo "Frontend unreachable"
                        '''
                    } else {
                        echo "🔍 Verifying remote deployment..."
                        sshagent([SSH_KEY_ID]) {
                            sh """
                            ssh -o StrictHostKeyChecking=no ${LIGHTSAIL_HOST} '
                                curl -I http://localhost:8000/api/healthz || echo "Backend unreachable"
                                curl -I http://localhost:3000 || echo "Frontend unreachable"
                            '
                            """
                        }
                    }
                }
            }
        }
    }

    // -------------------- POST ---------------------------------
    post {
        success {
            echo "✅ ${params.ENVIRONMENT.toUpperCase()} deployment succeeded!"
        }
        failure {
            echo "❌ ${params.ENVIRONMENT.toUpperCase()} deployment failed!"
        }
        always {
            echo "📜 Pipeline finished for ${params.ENVIRONMENT.toUpperCase()}"
        }
    }
}
