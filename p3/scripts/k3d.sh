#!/bin/bash

set -e

source ./utils/constants.sh

COLOR="${1:-${BOLD_GREEN}}"


echo -e "${COLOR}[k3d: 1/3] Installing k3d${RESET}"
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo -e "${COLOR}[k3d: 2/3] Creating ${CLUSTER_NAME} cluster${RESET}"
k3d cluster delete "${CLUSTER_NAME}" > /dev/null 2>&1
k3d cluster create "${CLUSTER_NAME}"

echo -e "${COLOR}[k3d: 3/3] Exporting kubeconfig${RESET}"
export KUBECONFIG=$(k3d kubeconfig write "${CLUSTER_NAME}")
