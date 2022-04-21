#!/bin/bash
export PATH="$PWD/bin":$PATH
nvm use "stable"
source ".venv/bin/activate"
source <(minikube completion bash)
source <(kubectl completion bash)
complete -C "${PWD}/bin/aws_completer" aws
export SCHEMAS_DIR="${PWD}/external/dev/service/app-sre/qontract-schemas/schemas"
export GRAPHQL_SCHEMAS_DIR="${PWD}/external/dev/app-sre/qontract-schemas/graphql-schemas"
