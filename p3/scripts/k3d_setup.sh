#!/bin/bash

set -e

BOLD_GREEN='\033[1;32m'
RESET='\033[0m'

echo -e "${BOLD_GREEN}[Setting up k3d cluster...]${RESET}"

echo -e "${BOLD_GREEN}[1/9] Creating k3d cluster${RESET}"
k3d cluster delete iot # delete if exists
k3d cluster create iot

export KUBECONFIG=$(k3d kubeconfig write iot)

echo -e "${BOLD_GREEN}[1/7] Creating argocd namespace${RESET}"
kubectl create namespace argocd

echo -e "${BOLD_GREEN}[2/7] Installing argocd${RESET}"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo -e "${BOLD_GREEN}[3/7] Waiting for argocd-initial-admin-secret to be created...${RESET}"
kubectl wait -n argocd --for=create secret argocd-initial-admin-secret --timeout=60s

echo -e "${BOLD_GREEN}[4/7] Getting argocd password${RESET}"
kubectl get -n argocd secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d > ../argocd_password.txt

echo -e "${BOLD_GREEN}[5/7] Waiting for argocd pods to be ready...${RESET}"
kubectl wait -n argocd --for=condition=Ready pods --all --timeout=120s

echo -e "${BOLD_GREEN}[6/7] Applying application${RESET}"
kubectl apply -n argocd -f ../confs/application.yml

echo -e "${BOLD_GREEN}[7/7] Port forwarding argocd to 8080${RESET}"
kubectl port-forward -n argocd service/argocd-server 8080:443 &

echo -e "${BOLD_GREEN}Setup complete${RESET}"
echo -e "${BOLD_GREEN}Press Ctrl+C to stop port forwarding${RESET}"
wait