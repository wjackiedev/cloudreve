#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

VERSION="${VERSION:-v4.17.0}"
IMAGE="${IMAGE:-registry.extscreen.com/xiaoyou/cloudreve:v4.17.0-obs-callback.1}"
PLATFORM="${PLATFORM:-linux/amd64}"
GO_VERSION="${GO_VERSION:-}"
NODE_VERSION="${NODE_VERSION:-}"
GOCACHE="${GOCACHE:-${TMPDIR:-/tmp}/cloudreve-gocache}"
GOMODCACHE="${GOMODCACHE:-${TMPDIR:-/tmp}/cloudreve-gomodcache}"
COMMIT="${COMMIT:-$(git rev-parse --short HEAD)}"

use_go() {
  local env_file=""

  if [ -n "${GO_VERSION}" ]; then
    env_file="${HOME}/.gvm/environments/${GO_VERSION}"
  elif [ -s "${HOME}/.gvm/environments/default" ]; then
    env_file="${HOME}/.gvm/environments/default"
  fi

  if [ -n "${env_file}" ] && [ -s "${env_file}" ]; then
    # shellcheck disable=SC1090
    source "${env_file}"
  fi

  echo "Using go: $(go version)"
}

use_node() {
  if command -v fnm >/dev/null 2>&1; then
    local fnm_env=""
    if fnm_env="$(fnm env --shell bash 2>/dev/null)"; then
      eval "${fnm_env}"
    else
      echo "fnm env failed; using current node environment"
    fi

    if [ -n "${NODE_VERSION}" ]; then
      fnm use "${NODE_VERSION}"
    fi
  else
    echo "fnm not found; using current node: $(node --version)"
  fi

  if command -v corepack >/dev/null 2>&1; then
    corepack enable
  fi

  echo "Using node: $(node --version)"
  echo "Using yarn: $(yarn --version)"
}

echo "==> Preparing toolchains"
use_go
use_node

echo "==> Installing frontend dependencies"
pushd assets >/dev/null
yarn install --network-timeout 1000000

echo "==> Building frontend assets"
yarn run build
popd >/dev/null

echo "==> Writing frontend version ${VERSION}"
printf '{"name":"cloudreve-frontend","version":"%s"}' "${VERSION}" > assets/build/version.json

echo "==> Packing embedded static assets"
zip -qr - assets/build > application/statics/assets.zip

echo "==> Building linux amd64 Cloudreve binary"
CGO_ENABLED=0 \
GOOS=linux \
GOARCH=amd64 \
GOCACHE="${GOCACHE}" \
GOMODCACHE="${GOMODCACHE}" \
go build \
  -ldflags "-s -w -X github.com/cloudreve/Cloudreve/v4/application/constants.BackendVersion=${VERSION} -X github.com/cloudreve/Cloudreve/v4/application/constants.LastCommit=${COMMIT}" \
  -o cloudreve

echo "==> Building and pushing Docker image ${IMAGE}"
docker buildx build \
  --platform="${PLATFORM}" \
  --provenance=false \
  -t "${IMAGE}" \
  --push \
  .

echo "==> Done: ${IMAGE}"
