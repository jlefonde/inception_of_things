#!/bin/bash

set -e

BOLD_GREEN='\033[1;32m'
RESET='\033[0m'

echo -e "${BOLD_GREEN}[Setting up k3d cluster...]${RESET}"

echo -e "${BOLD_GREEN}[1/11] Creating k3d cluster${RESET}"
k3d cluster delete iot # delete if exists
k3d cluster create iot

export KUBECONFIG=$(k3d kubeconfig write iot)

echo -e "${BOLD_GREEN}[2/11] Installing gitlab${RESET}"
helm upgrade -n gitlab --install gitlab gitlab/gitlab --create-namespace --timeout 600s -f ../confs/values_k3d.yml

echo -e "${BOLD_GREEN}[3/11] Waiting for gitlab-gitlab-initial-root-password to be created...${RESET}"
kubectl wait -n gitlab --for=create secret gitlab-gitlab-initial-root-password --timeout=60s

echo -e "${BOLD_GREEN}[4/11] Getting gitlab password${RESET}"
kubectl get -n gitlab secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 -d > ../gitlab_password.txt

echo -e "${BOLD_GREEN}[5/11] Creating argocd namespace${RESET}"
kubectl create namespace argocd

echo -e "${BOLD_GREEN}[6/11] Installing argocd${RESET}"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo -e "${BOLD_GREEN}[7/11] Waiting for argocd-initial-admin-secret to be created...${RESET}"
kubectl wait -n argocd --for=create secret argocd-initial-admin-secret --timeout=60s

echo -e "${BOLD_GREEN}[8/11] Getting argocd password${RESET}"
kubectl get -n argocd secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d > ../argocd_password.txt

echo -e "${BOLD_GREEN}[9/11] Waiting for argocd pods to be ready...${RESET}"
kubectl wait -n argocd --for=condition=Ready pods --all --timeout=120s

echo -e "${BOLD_GREEN}[10/11] Applying application${RESET}"
kubectl apply -n argocd -f ../confs/application.yml

echo -e "${BOLD_GREEN}[11/11] Port forwarding argocd to 8080${RESET}"
kubectl port-forward -n argocd service/argocd-server 8080:443 &

echo -e "${BOLD_GREEN}Setup complete${RESET}"
echo -e "${BOLD_GREEN}Press Ctrl+C to stop port forwarding${RESET}"
wait
