
pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 15, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    environment {
        K8S_NAMESPACE = 'bookinfo'
        K8S_SERVER = 'https://127.0.0.1:6443'
        K8S_CA = '/etc/jenkins/bookinfo-ca.crt'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Validate and Deploy') {
            steps {
                withCredentials([
                    string(
                        credentialsId: 'bookinfo-k8s-token',
                        variable: 'K8S_TOKEN'
                    )
                ]) {
                    sh '''
                        set -eu

                        export KUBECONFIG
                        KUBECONFIG=$(mktemp)
                        chmod 600 "$KUBECONFIG"

                        PF_PID=""

                        cleanup() {
                            if [ -n "$PF_PID" ]; then
                                kill "$PF_PID" 2>/dev/null || true
                            fi
                            rm -f "$KUBECONFIG"
                        }
                        trap cleanup EXIT

                        kubectl config set-cluster bookinfo-k3s \
                          --server="$K8S_SERVER" \
                          --certificate-authority="$K8S_CA" \
                          --embed-certs=true

                        kubectl config set-credentials jenkins-deployer \
                          --token="$K8S_TOKEN"

                        kubectl config set-context bookinfo \
                          --cluster=bookinfo-k3s \
                          --user=jenkins-deployer \
                          --namespace="$K8S_NAMESPACE"

                        kubectl config use-context bookinfo

                        echo "Validating manifests..."
                        kubectl apply --dry-run=server \
                          -f kubernetes/bookinfo.yaml

                        echo "Deploying Bookinfo..."
                        kubectl apply -f kubernetes/bookinfo.yaml

                        echo "Checking rollouts..."
                        for deployment in \
                          details-v1 ratings-v1 \
                          reviews-v1 reviews-v2 reviews-v3 \
                          productpage-v1
                        do
                          kubectl rollout status \
                            deployment/"$deployment" \
                            --timeout=180s
                        done

                        echo "Starting application smoke test..."
                        kubectl port-forward \
                          svc/productpage 19080:9080 \
                          > /tmp/bookinfo-port-forward-$$.log 2>&1 &
                        PF_PID=$!

                        SUCCESS=0
                        for attempt in $(seq 1 15); do
                            if curl --fail --silent --show-error \
                              --max-time 10 \
                              http://127.0.0.1:19080/productpage \
                              -o /dev/null; then
                                SUCCESS=1
                                break
                            fi
                            sleep 2
                        done

                        if [ "$SUCCESS" -ne 1 ]; then
                            echo "Smoke test failed"
                            exit 1
                        fi

                        echo "Bookinfo deployment successful!"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'Bookinfo CI/CD pipeline completed successfully.'
        }
        failure {
            echo 'Bookinfo CI/CD pipeline failed. Review console output.'
        }
    }
}
