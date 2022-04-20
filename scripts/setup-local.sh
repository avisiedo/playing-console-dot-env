#!/bin/bash

# Follow the steps at:
# https://consoledot.pages.redhat.com/docs/dev/getting-started/local/environment.html
set -e

# VARIABLES
# shellcheck disable=SC1091
[ ! -e scripts/private.inc.sh ] || source "scripts/private.inc.sh"
[ ! -e scripts/variables.inc.sh ] || source "scripts/variables.inc.sh"
source "scripts/helper.inc.sh"

function validation {
  if [ "${quayio_user}" == "" ]; then
      msg_error "The 'quayio_user' variable can not be empty. Set variable quayio_user to the username at quayio"
      exit 1
  fi

  if [ "${quayio_pull_secret_path}" == "" ] \
    || [ ! -e "${quayio_pull_secret_path}" ]; then
    msg_error "The 'quayio_pull_secret_path' variable is empty or the path does not exist"
    msg_error "Set the 'quayio_pull_secret_path' to pointing out to yours; by default it try 'quayio-pull-secret.yaml'"
    msg_info "Retrieve the information as indicated here:"
    msg_info "https://consoledot.pages.redhat.com/docs/dev/getting-started/local/environment.html#_get_your_quay_pull_secret"
    exit 1
  fi
}

function create_dirs {
  [ -e .cache ] || mkdir .cache
  [ -e bin ] || mkdir -p bin
}

function install_git {
  # Install git
  command -v git &>/dev/null || {
    msg_info "> Installing git"
    sudo dnf install -y git
  }
}

function install_virsh {
  command -v virsh &>/dev/null || {
    msg_info "> Installing virtualization packages"
    sudo dnf install -y @virtualization
    sudo usermod -a -G libvirt $(whoami)
    newgrp libvirt
  }
}


function install_aws_cli {
  [ -e .cache ] || mkdir .cache
  [ -e .cache/awscliv2.zip ] || curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o ".cache/awscliv2.zip"
  [ -e "${PWD}/.cache/aws-cli" ] || {
    [ -e .cache/aws ] || unzip ".cache/awscliv2.zip" -d ".cache"
    ".cache/aws/install" --install-dir "${PWD}/.cache/aws-cli" -b "${PWD}/bin"
  }
  [ ! -e ".cache/aws" ] || rm -rf ".cache/aws"
}


function install_minikube {
  # Install minikube
  # https://minikube.sigs.k8s.io/docs/start/
  [ -e "bin/minikube" ] || {
    msg_info "> Installing minikube"
    [ -e "bin" ] || mkdir "bin"
    curl -sLo "bin/minikube" "${minikube_url}"
    chmod a+x "bin/minikube"
  }
}


function install_kubectl {
  # Download kubectl
  # https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/

  [ -e "bin/kubectl" ] || {
    msg_info "> Installing kubectl"
    curl -sLo "bin/kubectl" "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod a+x "bin/kubectl"
    alias kubectl="$PWD/bin/kubectl"
  }
}


function configure_minikube {
  # Configure minikube
  msg_info "> Configuring minikube"
  minikube config set cpus "${minikube_cpus}"
  minikube config set memory "${minikube_memory}"
  minikube config set disk-size "${minikube_disk_size}"
  minikube config set vm-driver "${minikube_vm_driver}"
}

function start_minikube {
  # Start minikube
  msg_info "> Starting minikube"
  minikube start \
    --cpus "${minikube_cpus}" \
    --memory "${minikube_memory}" \
    --disk-size "${minikube_disk_size}" \
    --vm-driver "${minikube_vm_driver}"
}

function enable_minikube_addons {
  # Enable internal image registry at port 5000 in the minikube vm
  msg_info "> Enable minikube addons"
  minikube addons enable registry
  minikube addons enable ingress
}

function install_clowder {
  # Install clowder
  msg_info "> Installing clowder"
  [ -e .cache/kube_setup.sh ] || {
    curl -sLo .cache/kube_setup.sh https://raw.githubusercontent.com/RedHatInsights/clowder/master/build/kube_setup.sh
  }
  chmod +x .cache/kube_setup.sh
  ./.cache/kube_setup.sh
  # Check on this page if this is the last version:
  # https://github.com/RedHatInsights/clowder/releases/
  kubectl apply -f https://github.com/RedHatInsights/clowder/releases/download/${clouder_version}/clowder-manifest-${clouder_version}.yaml --validate=false
}

function create_and_setup_namespace {
  # Create namespace and configure it
  msg_info "> Creating and setup namespace '${namespace}'"
  kubectl get namespace "${namespace}" &>/dev/null \
  || kubectl create namespace "${namespace}"
  kubectl config set-context --current --namespace="${namespace}"
  kubectl get "secrets/${quayio_user}-pull-secret" &>/dev/null \
  || kubectl create -f "${quayio_pull_secret_path}"
}

function install_python_dependencies {
  # Install python dependencies
  msg_info "> Preparing .venv python environment"
  [ -e .venv ] || python -m venv .venv
  # shellcheck disable=SC1091
  source .venv/bin/activate
  pip install --upgrade pip
  pip install -r requirements-dev.txt
}

function setup_node_environment {
  # Preparing node environment by using nvm
  # https://github.com/nvm-sh/nvm
  msg_info "> Setting up node environment"
  command -v nvm &>/dev/null || {
    curl -sL https://raw.githubusercontent.com/creationix/nvm/master/install.sh | env -i HOME="$HOME" bash
  }

  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

  # TODO Set version in a variable
  nvm install v17.8.0
  nvm use v17.8.0

  # Install yalc
  command -v yalc &>/dev/null \
  || npm install -g yalc

  # Install create-crc-app
  command -v create-crc-app &>/dev/null \
  || npm install -g create-crc-app
}

function deploy_environment {
  # Deploy a local environment
  msg_info "> Deploying local environment with bonfire"
  bonfire deploy-env -n "${namespace}" -u "${quayio_user}"
  # bonfire deploy \
  #   --namespace "${namespace}"
  #   --source appsre \
  #   --local-config-path "config/bonfire-local.yaml" \
  #   --clowd-env "env-${namespace}"
}


function clone_repo_to_directory {
  local repo="$1"
  local directory="$2"

  [ "${repo}" != "" ] || {
    msg_error "'repo' is empty"
    return 1
  }
  [ "${directory}" != "" ] || {
    msg_error "'directory' is empty"
    return 1
  }
  [ -e "${directory}" ] || {
    info_msg "> Cloning '${repo}' to '${directory}'"
    git clone -o downstream "${repo}" "${directory}"
  }
}


function download_external_repos {
  msg_info "> Downloading necessary repositories?"

  repos=()
  repos+=("https://github.com/RedHatInsights/frontend-components.git")
  repos+=("https://github.com/RedHatInsights/insights-chrome.git")
  repos+=("https://github.com/RedHatInsights/insights-host-inventory.git")
  repos+=("https://github.com/app-sre/qontract-server.git")
  repos+=("https://github.com/RedHatInsights/cloud-services-config.git")
  repos+=("https://github.com/RedHatInsights/image-builder-frontend.git")
  repos+=("https://github.com/RedHatInsights/image-builder-frontend.git")
  repos+=("https://github.com/RedHatInsights/insights-remediations-frontend.git")
  repos+=("https://github.com/RedHatInsights/insights-remediations.git")
  repos+=("https://github.com/RedHatInsights/remediations-consumer.git")
  repos+=("https://github.com/RedHatInsights/rbac-config.git")

  for repo in "${repos[@]}"; do
    directory="${repo##*/}"
    directory="${directory%.git}"
    directory="external/${directory}"
    clone_repo_to_directory "${repo}" "${directory}"
  done
}


function download_appsre_repos {
  # https://gitlab.cee.redhat.com/service/app-interface/-/blob/master/docs/app-sre/sop/app-interface-development-environment-setup.md#setup-repo
  [ -e external/dev/app-sre ] || mkdir -p external/dev/app-sre
  [ -e external/dev/service ] || mkdir -p external/dev/service

  repos=()
  repos+=("https://gitlab.cee.redhat.com/service/app-interface.git")
  for r in "${repos[@]}"; do
    directory="${r##*/}"
    directory="${directory%.git}"
    directory="external/dev/service/${directory}"
    clone_repo_to_directory "${r}" "${directory}"
  done
  (cd external/dev/service/app-interface; git checkout Makefile; git apply ../../../../config/patches/dev/service/app-interface/0001-patch-makefile-dirs.patch)

  repos=()
  repos+=("https://github.com/app-sre/qontract-server.git")
  repos+=("https://github.com/app-sre/qontract-reconcile.git")
  repos+=("https://github.com/app-sre/qontract-schemas.git")
  for r in "${repos[@]}"; do
    directory="${r##*/}"
    directory="${directory%.git}"
    directory="external/dev/app-sre/${directory}"
    clone_repo_to_directory "${r}" "${directory}"
  done

  [ -e "external/dev/service/app-interface/schema" ] || {
    ln -svf "../../app-sre/qontract-schemas/schemas" "external/dev/service/app-interface/schemas"
  }
  [ -e "external/dev/service/app-interface/graphql-schemas" ] || {
    ln -svf "../../app-sre/qontract-schemas/graphql-schemas" "external/dev/service/app-interface/graphql-schemas"
  }
}


function install_podman {
  # Install podman if not yet
  command -v podman &>/dev/null || {
    msg_info "> Installing podman"
    sudo dnf install -y podman
  }
}

# https://consoledot.pages.redhat.com/docs/dev/getting-started/local/development.html#_a_combined_local_build_sh
function generate_local_build {
  cat <<EOF
DEFAULT_APP=\$(dirname "\${PWD}")
DEFAULT_APP="${APP##*/}"
APP="\${\$1:-\${DEFAULT_APP}}"

VERSION="\${VERSION:-"0.0.0"}"
VERSION="${VERSION}-$(git rev-list --count HEAD)"

if [ -z "\${APP}" ]; then
  echo "usage ./local_build.sh <app>\n"
  echo "It looks like you may be missing the app arg.\n"
fi

TAG=\$( cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 7 | head -n 1 )
IMAGE="127.0.0.1:5000/\${APP}"

podman build -t \$IMAGE:\$TAG -f Dockerfile

podman push \$IMAGE:\$TAG \$(minikube ip):5000/\${APP}:\${TAG} --tls-verify=false
echo \$TAG
EOF
}

# PROCESS

validation
create_dirs
export PATH="$PWD/bin:$PATH"
install_git
install_virsh
install_aws_cli
install_minikube
install_kubectl
install_podman

download_external_repos
download_appsre_repos

configure_minikube
start_minikube
enable_minikube_addons
install_clowder
create_and_setup_namespace
install_python_dependencies
setup_node_environment
deploy_environment



# Install an application by:
# bonfire deploy --source=appsre rbac -n test

# For each application:
# git clone -o downstream "https://github.com/RedHatInsights/${app}.git" "external/${app}"

# Generate bonfire defaults
# bonfire config write-default # By default it writes at ~/.config/bonfire/config.yaml
# bonfire config write-default config/bonfire-config.yaml
#
# bonfire deploy --local-config-path config/bonfire-config-local.yaml -n "${namespace}"




# About bonfire
# https://github.com/RedHatInsights/bonfire/blob/master/README.md


# Creating minimal frontend
# See repo: https://github.com/RedHatInsights/frontend-starter-app


# Create application
APP=insights-idm
export APP
[ -e "external/${APP}-frontend" ] || {
	msg_info "> Creating frontend application at 'external/${APP}'"
  # FIXME 'npm install --save webpack-bundle-analyzer' is needed to do 'npm run build' and './node_modules/.bin/fec static'
	(cd external && create-crc-app "${APP}-frontend" && cd "${APP}-frontend" && npm install --save webpack-bundle-analyzer)
  generate_local_build > "external/${APP}-frontend/local_build.sh"
  chmod a+x "external/${APP}-frontend/local_build.sh"
}

cat <<EOF
Now load the environment by:
# source config/prepare-env.sh
Now go to external/${APP}-frontend
# cd external/${APP}-frontend
And run the frontend by:
# PROXY=yes npm run dev
EOF

# Configure the proxy paths at: fec.config.js
# Use the 'routesPath' attribute to externalize
# the definition in an external file.

# More information about it at:
# https://github.com/RedHatInsights/frontend-components/tree/master/packages/config#useproxy

# To use the environment setup by this script, just do:
# source config/prepare-env.sh

# bonfire deploy --local-config-path config/bonfire-local.yaml -n "${namespace}"
