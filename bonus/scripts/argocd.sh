#!/bin/bash

set -e

source ./utils/constants.sh

COLOR="${1:-${BOLD_GREEN}}"

echo -e "${COLOR}[argocd: 1/6] Creating argocd namespace${RESET}"
kubectl create namespace argocd

echo -e "${COLOR}[argocd: 2/6] Installing argocd${RESET}"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo -e "${COLOR}[argocd: 3/6] Waiting for argocd pods to be ready...${RESET}"
kubectl wait -n argocd pods --all --for=condition=Ready --timeout=120s

echo -e "${COLOR}[argocd: 4/6] Exporting argocd password${RESET}"
kubectl get -n argocd secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d > ./argocd_password.txt

echo -e "${COLOR}[argocd: 5/6] Applying application${RESET}"
kubectl apply -n argocd -f ../confs/application.yml

echo -e "${COLOR}[argocd: 6/6] Forwarding argocd to ${ARGOCD_PORT}${RESET}"
kubectl port-forward -n argocd service/argocd-server "${ARGOCD_PORT}":443 > /dev/null 2>&1 &
