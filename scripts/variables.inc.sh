#!/bin/bash

repo_user="${repo_user:-${USER}}"

minikube_cpus="${minikube_cpus:-6}"
minikube_memory="${minikube_memory:-16384}"
minikube_disk_size="${minikube_disk_size:-36GB}"
minikube_vm_driver="${minikube_vm_driver:-kvm2}"

minikube_url="${minikube_url:-https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64}"

# https://github.com/RedHatInsights/clowder/releases/
clouder_version="v0.30.0"


# TODO Fill this or provide externally
quayio_user="${quayio_user:-${USER}}"
quayio_pull_secret_path="${quayio_pull_secret_path:-quay-io-pull-secret.yaml}"

namespace="${namespace:-console-idm}"

bonfire_config_path="config/bonfire-local.yaml"

insights_chrome_build="${PWD}/external/frontend-components/insights-chrome/build"
