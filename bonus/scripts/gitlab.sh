#!/bin/bash

set -e

source ./utils/constants.sh

COLOR="${1:-${BOLD_GREEN}}"

GITLAB_HOST=$(grep "127.0.0.1       gitlab.app.com" /etc/hosts | awk '{print $1}')

if [ -z "$GITLAB_HOST" ]; then
  echo "127.0.0.1       gitlab.app.com" | sudo tee -a /etc/hosts > /dev/null 2>&1
fi

echo -e "${COLOR}[gitlab: 1/12] Adding gitlab chart to helm repository${RESET}"
helm repo add gitlab https://charts.gitlab.io/

echo -e "${COLOR}[gitlab: 2/12] Updating helm repository${RESET}"
helm repo update

echo -e "${COLOR}[gitlab: 3/12] Installing gitlab${RESET}"
helm upgrade -n gitlab --create-namespace --install gitlab gitlab/gitlab -f ../confs/values_k3d.yml --timeout 600s

echo -e "${COLOR}[gitlab: 4/12] Waiting for gitlab webservice to be ready...${RESET}"
kubectl wait -n gitlab pod -l app=webservice --for=condition=Ready --timeout=600s

echo -e "${COLOR}[gitlab: 5/12] Exporting argocd password${RESET}"
kubectl get -n gitlab secret gitlab-gitlab-initial-root-password -o jsonpath="{.data.password}" | base64 -d > ./gitlab_password.txt
GITLAB_PASSWORD=$(cat ./gitlab_password.txt)

echo -e "${COLOR}[gitlab: 6/12] Forwarding gitlab to ${GITLAB_PORT}${RESET}"
kubectl port-forward -n gitlab service/gitlab-webservice-default "${GITLAB_PORT}":8181 > /dev/null 2>&1 &

echo -e "${COLOR}[gitlab: 7/12] Waiting for gitlab to be accessible...${RESET}"
end=$((SECONDS + 60))
while [[ $SECONDS -lt $end ]]; do
  if curl -s -o /dev/null -w "%{http_code}" http://localhost:${GITLAB_PORT} | grep -q "302"; then
      break
  fi
  sleep 2
done || (echo -e "${BOLD_RED} Gitlab is not accessible${RESET}" && exit 1)

echo -e "${COLOR}[gitlab: 8/12] Creating gitlab repository${RESET}"
GITLAB_TOKEN=$(curl -s -X POST "http://localhost:${GITLAB_PORT}/oauth/token" \
  -d "grant_type=password&username=root&password=${GITLAB_PASSWORD}" | jq -r .access_token)

curl -s -o /dev/null -X POST "http://localhost:${GITLAB_PORT}/api/v4/projects" \
  -H "Authorization: Bearer ${GITLAB_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"inception_of_things_conf\",
    \"visibility\": \"public\"
  }"

echo -e "${COLOR}[gitlab: 9/12] Creating gitlab token${RESET}"
GITLAB_PAT_NAME="iot"
GITLAB_PAT=$(curl -s -X POST "http://localhost:${GITLAB_PORT}/api/v4/users/1/personal_access_tokens" \
  -H "Authorization: Bearer ${GITLAB_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"${GITLAB_PAT_NAME}\",
    \"scopes\": [\"api\", \"read_repository\", \"write_repository\"],
	\"expires_at\": \"$(date '+%Y-%m-%d' -d '1 month')\"
  }" | jq -r .token)

echo -e "${COLOR}[gitlab: 10/12] Cloning gitlab repository${RESET}"
rm -rf ../../../iot_conf
git clone http://${GITLAB_PAT_NAME}:${GITLAB_PAT}@localhost:${GITLAB_PORT}/root/inception_of_things_conf.git  ../../../iot_conf > /dev/null 2>&1

echo -e "${COLOR}[gitlab: 11/12] Copying config files${RESET}"
cd ../../../iot_conf
git clone https://github.com/jlefonde/inception_of_things_conf.git /tmp/inception_of_things_conf

rm -rf /tmp/inception_of_things_conf/.git
cp -r  /tmp/inception_of_things_conf/* .
rm -rf /tmp/inception_of_things_conf

USER_EMAIL=$(curl -s "http://localhost:8181/api/v4/user/emails" \
	-H "Authorization: Bearer ${GITLAB_TOKEN}" | jq '.[0]'.email)

echo -e "${COLOR}[gitlab: 12/12] Pushing config files to gitlab${RESET}"
git config --local user.name "Administrator"
git config --local user.email ${USER_EMAIL}
git add -A
git commit -m "Added config files"
git push
