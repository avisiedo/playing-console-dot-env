#!/bin/bash

# Follow the steps at:
# https://consoledot.pages.redhat.com/docs/dev/getting-started/local/environment.html
set -e

# shellcheck disable=SC1091
[ ! -e scripts/private.inc.sh ] || source "scripts/private.inc.sh"

# VARIABLES
repo_user="${repo_user:-${USER}}"

minikube_cpus="6"
minikube_memory="16384"
minikube_disk_size="36GB"
minikube_vm_driver="kvm2"

minikube_url="https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64"

# https://github.com/RedHatInsights/clowder/releases/
clouder_version="v0.30.0"

# TODO Fill this or provide externally
quayio_user="${quayio_user:-${USER}}"
quayio_pull_secret_path="${quaio_pull_secret_path:-quay-io-pull-secret.yaml}"

namespace="${namespace:-idm}"

# INSIGHTS_CHROME="${PWD}/external/frontend-components/insights-chrome/build"

# VALIDATION

if [ "${quayio_user}" == "" ]; then
    echo "ERROR:quayio_user can not be empty. Set variable quayio_user to the username at quayio"
    exit 1
fi

if [ "${quayio_pull_secret_path}" == "" ] \
   || [ ! -e "${quayio_pull_secret_path}" ]; then
  echo "ERROR:quayio_pull_secret_path is empty or the path does not exist"
  echo "ERROR:Set quayio_pull_secreto pointing out to yours; by default it try 'quayio-pull-secret.yaml'"
  echo "INFO:Retrieve the information as indicated here:"
  echo "INFO:https://consoledot.pages.redhat.com/docs/dev/getting-started/local/environment.html#_get_your_quay_pull_secret"
  exit 1
fi

# PROCESS

[ -e .cache ] || mkdir .cache
[ -e bin ] || mkdir -p bin
export PATH="$PWD/bin:$PATH"

# Install git
command -v git &>/dev/null || {
	echo "> Installing git"
	sudo dnf install -y git
}

command -v virsh &>/dev/null || {
	echo "> Installing virtualization packages"
	sudo dnf install -y @virtualization
}


# Install minikube
# https://minikube.sigs.k8s.io/docs/start/
[ -e "bin/minikube" ] || {
	echo "> Installing minikube"
	[ -e "bin" ] || mkdir "bin"
	curl -sLo "bin/minikube" "${minikube_url}"
	chmod a+x "bin/minikube"
}

# Download kubectl
# https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/

[ -e "bin/kubectl" ] || {
	curl -sLo "bin/kubectl" "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
	chmod a+x "bin/kubectl"
	alias kubectl="$PWD/bin/kubectl"
}

# Configure minikube
minikube config set cpus "${minikube_cpus}"
minikube config set memory "${minikube_memory}"
minikube config set disk-size "${minikube_disk_size}"
minikube config set vm-driver "${minikube_vm_driver}"

# Start minikube
echo "> Starting minikube"
minikube start \
  --cpus "${minikube_cpus}" \
  --memory "${minikube_memory}" \
  --disk-size "${minikube_disk_size}" \
  --vm-driver "${minikube_vm_driver}"
# Enable internal image registry at port 5000 in the minikube vm
minikube addons enable registry

# Install clowder
echo "> Install clowder"
curl -sLo .cache/kube_setup.sh https://raw.githubusercontent.com/RedHatInsights/clowder/master/build/kube_setup.sh
chmod +x .cache/kube_setup.sh
./.cache/kube_setup.sh
# Check on this page if this is the last version:
# https://github.com/RedHatInsights/clowder/releases/
kubectl apply -f https://github.com/RedHatInsights/clowder/releases/download/${clouder_version}/clowder-manifest-${clouder_version}.yaml --validate=false

# Create namespace and configure it
kubectl get namespace "${namespace}" \
|| kubectl create namespace "${namespace}"
kubectl config set-context --current --namespace="${namespace}"
kubectl get "secrets/${quayio_user}-pull-secret" \
|| kubectl create -f "${quayio_pull_secret_path}"

# Install python dependencies
echo "> Preparing .venv python environment"
[ -e .venv ] || python -m venv .venv
# shellcheck disable=SC1091
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements-dev.txt

# Preparing node environment by using nvm
# https://github.com/nvm-sh/nvm
which nvm &>/dev/null \
|| curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
source "$HOME/.bashrc"
# TODO Set version in a variable
nvm install v17.8.0
nvm use v17.8.0
npm install -g yalc

# Deploy an ephemeral cloud environment
echo "> Deploying ephemeral cloud environment"
bonfire deploy-env -n "${namespace}" -u "${quayio_user}"

# Install an application by:
# bonfire deploy --source=appsre rbac -n test

# For each application:
# git clone -o downstream "https://github.com/RedHatInsights/${app}.git" "external/${app}"

# Generate bonfire defaults
# bonfire config write-default # By default it writes at ~/.config/bonfire/config.yaml
# bonfire config write-default config/bonfire-config.yaml
# INFO I do not know yet how to specify a specific configuration file
# INFO I would like to have a self-contained environment, no other configuration file
#      out of the current base directory.
echo "> Downloading necessary repositories?"
apps=()
#apps+=("insights-rbac")
#apps+=("landing-page-frontend")
apps+=("frontend-components")
for app in "${apps[@]}"; do
    [ -e "./external/${app}" ] \
    || git clone -o downstream "https://github.com/RedHatInsights/${app}.git" "external/${app}"
done

# Install podman if not yet
command -v podman &>/dev/null \
|| sudo dnf install -y podman

# https://consoledot.pages.redhat.com/docs/dev/getting-started/local/development.html#_a_combined_local_build_sh
echo "> Use similar template for each repo to develop"
cat <<EOF
APP=\$1

if [ -z "\$APP" ]; then
  echo "usage ./local_build.sh <app>\n"
  echo "It looks like you may be missing the app arg.\n"
fi

TAG=\$( cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 7 | head -n 1 )
IMAGE="127.0.0.1:5000/\$APP"

podman build -t \$IMAGE:\$TAG -f Dockerfile

podman push \$IMAGE:\$TAG \$(minikube ip):5000/\$APP:\$TAG --tls-verify=false
echo \$TAG
EOF

# About bonfire
# https://github.com/RedHatInsights/bonfire/blob/master/README.md


# Creating minimal frontend
# See repo: https://github.com/RedHatInsights/frontend-starter-app

# Install create-crc-app
command -v create-crc-app &>/dev/null || {
	npm install -g create-crc-app
}


# Create application
APP=console-idm
export APP
(cd external; create-crc-app "$APP")

# start the application with 'PROXY=yes'
# PROXY=true npm run dev

# Configure the proxy paths at: fec.config.js
# Use the 'routesPath' attribute to externalize
# the definition in an external file.

# More information about it at:
# https://github.com/RedHatInsights/frontend-components/tree/master/packages/config#useproxy


# At the end of this script, just include the config/prepare-env.sh
# to set the environment before work with it
source config/prepare-env.sh


