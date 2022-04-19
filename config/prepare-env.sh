#!/bin/bash
export PATH="$PWD/bin":$PATH
nvm use "stable"
source ".venv/bin/activate"
source <(minikube completion bash)
source <(kubectl completion bash)
complete -C "${PWD}/bin/aws_completer" aws
