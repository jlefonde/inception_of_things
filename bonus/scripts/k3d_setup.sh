#!/bin/bash

set -e

kubectl wait -n kube-system --for=create svc traefik --timeout=120s

EXTERNAL_IP=""
while [ -z "$EXTERNAL_IP" ]; do
  echo "Waiting for external IP"
  EXTERNAL_IP=$(kubectl get -n kube-system svc traefik --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
  [ -z "$EXTERNAL_IP" ] && sleep 1
done

OLD_EXTERNAL_IP=$(grep gitlab.app.com /etc/hosts | awk '{print $1}')

if [ -z "$OLD_EXTERNAL_IP" ]; then
  sudo echo "$EXTERNAL_IP    gitlab.app.com" >> /etc/hosts
else
  sudo sed -i 's/'$OLD_EXTERNAL_IP'/'$EXTERNAL_IP'/g' /etc/hosts
fi

echo -e "${BOLD_GREEN}[2/11] Installing gitlab${RESET}"
helm upgrade -n gitlab --install gitlab gitlab/gitlab --create-namespace --timeout 600s --set global.hosts.externalIP=$EXTERNAL_IP -f ../confs/values_k3d.yml

echo -e "${BOLD_GREEN}[4/11] Getting gitlab password${RESET}"
kubectl get -n gitlab secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 -d > ../gitlab_password.txt
GITLAB_PASSWORD=$(cat ../gitlab_password.txt)

echo -e "${BOLD_GREEN}[5/11] Waiting for gitlab webservice pods to be ready...${RESET}"
kubectl wait -n gitlab --for=condition=Ready pods -l app=webservice --timeout=600s

echo -e "${BOLD_GREEN}[6/11] Waiting for gitlab to be accessible...${RESET}"
end=$((SECONDS + 60))
while [[ $SECONDS -lt $end ]]; do
    if curl -s -o /dev/null -w "%{http_code}" http://gitlab.app.com | grep -q "302"; then
        break
    fi
    sleep 2
done || (echo -e "${BOLD_RED} Gitlab is not accessible${RESET}" && exit 1)

echo -e "${BOLD_GREEN}[6/11] Creating GitLab project${RESET}"
export GITLAB_TOKEN=$(curl -s -X POST "http://gitlab.app.com/oauth/token" \
  -d "grant_type=password&username=root&password=$GITLAB_PASSWORD" | jq -r .access_token)

curl -s -X POST "http://gitlab.app.com/api/v4/projects" \
  -H "Authorization: Bearer $GITLAB_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"inception_of_things_conf\",
    \"visibility\": \"public\"
  }"

echo -e "${BOLD_GREEN}[7/11] Generating ssh key${RESET}"
ssh-keygen -t ed25519 -C "iot" -N "" -f ../id_ed25519

echo -e "${BOLD_GREEN}[8/11] Adding ssh key to gitlab${RESET}"
curl -X POST "http://gitlab.app.com/api/v4/user/keys" \
  -H "Authorization: Bearer $GITLAB_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"title\": \"iot\",
    \"key\": \"$(cat ../id_ed25519.pub)\"
  }"

echo -e "${BOLD_GREEN}[9/11] Cloning gitlab project${RESET}"
git clone http://root:$GITLAB_PASSWORD@gitlab.app.com/root/inception_of_things_conf.git ../../../iot_conf

echo -e "${BOLD_GREEN}[10/11] Copying config files${RESET}"
cp -R ../confs/repo/* ../../../iot_conf/

cd ../../../iot_conf
git config --local user.email "root@gitlab.app.com"
git config --local user.name "root"
git add -A
git commit -m "Added config files"
git push
cd -
