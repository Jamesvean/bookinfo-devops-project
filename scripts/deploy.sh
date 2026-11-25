
#!/usr/bin/env bash

set -Eeuo pipefail

NAMESPACE="${KUBE_NAMESPACE:-bookinfo}"
MANIFEST="kubernetes/bookinfo.yaml"
ROLLOUT_TIMEOUT="180s"
LOCAL_PORT="19080"

DEPLOYMENTS=(
    details-v1
    ratings-v1
    reviews-v1
    reviews-v2
    reviews-v3
    productpage-v1
)

BACKUP_DIR="$(mktemp -d)"
PF_PID=""
DEPLOY_STARTED=false

cleanup() {
    if [[ -n "$PF_PID" ]]; then
        kill "$PF_PID" 2>/dev/null || true
        wait "$PF_PID" 2>/dev/null || true
    fi

    rm -rf "$BACKUP_DIR"
}

rollback() {
    local failed=0

    echo "========================================"
    echo "Starting automatic rollback"
    echo "========================================"

    for deployment in "${DEPLOYMENTS[@]}"; do
        echo "Restoring $deployment"

        if ! kubectl -n "$NAMESPACE" patch deployment "$deployment" \
            --type=json \
            --patch-file="$BACKUP_DIR/$deployment.json"; then

            failed=1
        fi
    done

    for deployment in "${DEPLOYMENTS[@]}"; do
        if ! kubectl -n "$NAMESPACE" rollout status \
            "deployment/$deployment" \
            --timeout="$ROLLOUT_TIMEOUT"; then

            failed=1
        fi
    done

    if [[ "$failed" -eq 0 ]]; then
        echo "ROLLBACK SUCCESSFUL"
    else
        echo "ROLLBACK FAILED: Manual intervention required."
    fi

    return "$failed"
}

on_error() {
    local exit_code=$?

    trap - ERR
    set +e

    echo "Deployment failed with exit code: $exit_code"

    if [[ "$DEPLOY_STARTED" == "true" ]]; then
        rollback
    else
        echo "Deployment was not started. Rollback not required."
    fi

    exit "$exit_code"
}

trap cleanup EXIT
trap on_error ERR

echo "========================================"
echo "BOOKINFO AUTOMATED DEPLOYMENT"
echo "========================================"

echo "[1/6] Validating Kubernetes manifests"

kubectl -n "$NAMESPACE" apply \
    --dry-run=server \
    -f "$MANIFEST"

echo "[2/6] Backing up existing deployment templates"

for deployment in "${DEPLOYMENTS[@]}"; do

    kubectl -n "$NAMESPACE" get deployment "$deployment" \
        -o json | python3 -c '
import json
import sys

deployment = json.load(sys.stdin)

patch = [{
    "op": "replace",
    "path": "/spec/template",
    "value": deployment["spec"]["template"]
}]

json.dump(patch, sys.stdout)
' > "$BACKUP_DIR/$deployment.json"

    echo "Backup completed: $deployment"

done

echo "[3/6] Deploying Bookinfo application"

DEPLOY_STARTED=true

kubectl -n "$NAMESPACE" apply -f "$MANIFEST"

echo "[4/6] Checking deployment rollout status"

for deployment in "${DEPLOYMENTS[@]}"; do

    kubectl -n "$NAMESPACE" rollout status \
        "deployment/$deployment" \
        --timeout="$ROLLOUT_TIMEOUT"

done

echo "[5/6] Performing application smoke test"

kubectl -n "$NAMESPACE" port-forward \
    --address 127.0.0.1 \
    svc/productpage \
    "${LOCAL_PORT}:9080" \
    > "$BACKUP_DIR/port-forward.log" 2>&1 &

PF_PID=$!

SMOKE_PASSED=false

for attempt in {1..30}; do

    echo "Smoke test attempt: $attempt"

    if kill -0 "$PF_PID" 2>/dev/null && \
        curl --fail --silent --show-error \
        --max-time 5 \
        "http://127.0.0.1:${LOCAL_PORT}/productpage" \
        -o "$BACKUP_DIR/productpage.html"; then

        if grep -qi "BookInfo" "$BACKUP_DIR/productpage.html"; then
            SMOKE_PASSED=true
            break
        fi
    fi

    sleep 2

done

if [[ "$SMOKE_PASSED" != "true" ]]; then

    echo "ERROR: Bookinfo smoke test failed."

    cat "$BACKUP_DIR/port-forward.log"

    false

fi

echo "[6/6] Displaying Kubernetes resources"

kubectl -n "$NAMESPACE" get deployments
kubectl -n "$NAMESPACE" get pods
kubectl -n "$NAMESPACE" get services

echo "========================================"
echo "Bookinfo deployment successful!"
echo "All deployments are healthy."
echo "Application smoke test passed."
echo "========================================"
