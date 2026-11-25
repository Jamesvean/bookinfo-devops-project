
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 20, unit: 'MINUTES')
        skipDefaultCheckout(true)
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        KUBE_NAMESPACE = 'bookinfo'
        KUBE_SERVER = 'https://127.0.0.1:6443'
        KUBE_CA = '/etc/jenkins/bookinfo-ca.crt'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Validate Environment') {
            steps {
                sh '''
                    set -eu

                    echo "Checking required tools..."

                    command -v kubectl
                    command -v bash
                    command -v curl

                    kubectl version --client

                    test -f kubernetes/bookinfo.yaml
                    test -f scripts/deploy.sh
                    test -r "$KUBE_CA"

                    bash -n scripts/deploy.sh

                    echo "Environment validation successful."
                '''
            }
        }

        stage('Deploy Bookinfo') {
            steps {
                withCredentials([
                    string(
                        credentialsId: 'bookinfo-k8s-token',
                        variable: 'KUBE_TOKEN'
                    )
                ]) {
                    sh '''
                        set +x
                        set -eu

                        export KUBECONFIG="$(mktemp)"

                        chmod 600 "$KUBECONFIG"

                        trap 'rm -f "$KUBECONFIG"' EXIT

                        kubectl config set-cluster bookinfo-cluster \
                            --server="$KUBE_SERVER" \
                            --certificate-authority="$KUBE_CA" \
                            --embed-certs=true

                        kubectl config set-credentials jenkins-deployer \
                            --token="$KUBE_TOKEN"

                        kubectl config set-context bookinfo-context \
                            --cluster=bookinfo-cluster \
                            --user=jenkins-deployer \
                            --namespace="$KUBE_NAMESPACE"

                        kubectl config use-context bookinfo-context

                        echo "Starting automated deployment..."

                        bash scripts/deploy.sh
                    '''
                }
            }
        }

    }

    post {

        success {
            echo 'Bookinfo CI/CD pipeline completed successfully!'
            echo 'Deployment and smoke tests passed.'
        }

        failure {
            echo 'Bookinfo deployment pipeline failed.'
            echo 'Check deployment and rollback logs.'
        }

        always {
            echo 'Pipeline execution completed.'
        }
    }
}

