#!/usr/bin/env bash
set -euo pipefail

echo ">>> Using minikube context"
kubectl config use-context minikube >/dev/null

echo ">>> Make sure storage addons are enabled"
minikube addons enable storage-provisioner >/dev/null
minikube addons enable default-storageclass >/dev/null

echo ">>> Build images inside minikube docker"
eval "$(minikube docker-env)"

docker build -t techitfactory/churn-api:0.1.0 -f docker/Dockerfile.api .
docker build -t techitfactory/churn-ml:0.1.0 -f docker/Dockerfile.ml .

echo ">>> Apply all k8s resources"
kubectl apply -k k8s

echo ">>> Recreate seed job to populate production alias"
kubectl -n churn-mlops delete job churn-seed-model --ignore-not-found
kubectl -n churn-mlops apply -f k8s/seed-model-job.yaml

echo ">>> Wait for seed job logs"
kubectl -n churn-mlops logs -f job/churn-seed-model || true

echo ">>> Restart API"
kubectl -n churn-mlops rollout restart deployment/churn-api

echo ">>> Done ✅"
echo "Try: kubectl -n churn-mlops get pods"
