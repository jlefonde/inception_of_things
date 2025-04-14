#!/bin/bash

set -e

source ./utils/constants.sh

K3D_COLOR="${BOLD_BLUE}"
ARGOCD_COLOR="${BOLD_GREEN}"
GITLAB_COLOR="${BOLD_PURPLE}"

echo -e "${K3D_COLOR}=============== k3d ===============${RESET}"
./k3d.sh "${K3D_COLOR}"
echo -e "${K3D_COLOR}✓ k3d successfully installed${RESET}\n"

echo -e "${GITLAB_COLOR}=============== gitlab ===============${RESET}"
./gitlab.sh "${GITLAB_COLOR}"
echo -e "${GITLAB_COLOR}✓ gitlab successfully installed${RESET}\n"

echo -e "${ARGOCD_COLOR}=============== argocd ===============${RESET}"
./argocd.sh "${ARGOCD_COLOR}"
echo -e "${ARGOCD_COLOR}✓ argocd successfully installed${RESET}\n"

EXTERNAL_IP=$(kubectl get -n kube-system svc traefik --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
OLD_EXTERNAL_IP=$(awk '$2=="app.com" {print $1}' /etc/hosts)

if [ -z "${OLD_EXTERNAL_IP}" ]; then
  echo "${EXTERNAL_IP}       app.com" | sudo tee -a /etc/hosts > /dev/null 2>&1
else
  sudo sed -i 's/'${OLD_EXTERNAL_IP}'/'${EXTERNAL_IP}'/g' /etc/hosts
fi

echo -e "${GITLAB_COLOR}→ access gitlab at: http://localhost:${GITLAB_PORT}${RESET}"
echo -e "${ARGOCD_COLOR}→ access argocd at: https://localhost:${ARGOCD_PORT}${RESET}"
