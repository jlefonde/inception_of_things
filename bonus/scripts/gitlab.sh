#!/bin/bash

set -e

source ./utils/constants.sh

COLOR="${1:-${BOLD_GREEN}}"

echo -e "${COLOR}[gitlab: 1/6] Adding gitlab chart to helm repository${RESET}"
helm repo add gitlab https://charts.gitlab.io/

echo -e "${COLOR}[gitlab: 2/6] Updating helm repository${RESET}"
helm repo update

echo -e "${COLOR}[gitlab: 3/6] Installing gitlab in ${CLUSTER_NAME} cluster${RESET}"
helm upgrade -n gitlab --create-namespace \
  --install gitlab gitlab/gitlab \
  -f ../confs/values_k3d.yml \
  --set global.hosts.externalIP=0.0.0.0 \
  --set global.hosts.https=false \
  --timeout 600s

echo -e "${COLOR}[gitlab: 4/6] Waiting for gitlab webservice to be ready...${RESET}"
kubectl wait -n gitlab pod -l app=webservice --for=condition=Ready --timeout=600s

echo -e "${COLOR}[gitlab: 5/6] Exporting argocd password${RESET}"
kubectl get -n gitlab secret gitlab-gitlab-initial-root-password -o jsonpath="{.data.password}" | base64 -d > ./gitlab_password.txt

echo -e "${COLOR}[gitlab: 6/6] Forwarding gitlab to ${GITLAB_PORT}${RESET}"
kubectl port-forward -n gitlab service/gitlab-webservice-default "${GITLAB_PORT}":8080 > /dev/null 2>&1 &
