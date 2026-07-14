# Cloudreve v4.17.0 OBS Callback Image Maintenance Guide

This branch is based on Cloudreve `v4.17.0` and maintains only a narrow fix for OBS multipart upload callbacks.

## Patch Scope

- Backend: `pkg/filemanager/driver/obs/obs.go`
  - No longer appends `x-obs-callback` to the OBS `CompleteMultipartUpload` signed URL.
  - Keeps Cloudreve's existing upload session metadata and multipart completion flow.
- Frontend submodule: `assets`
  - Completes the OBS multipart upload first.
  - Then actively calls the Cloudreve callback endpoint from the frontend:
    `POST /callback/obs/{sessionId}/{callbackSecret}`.

This avoids depending on OBS to call Cloudreve back from the object storage side, while still allowing Cloudreve to correctly finish the upload session after the client completes the multipart upload.

## Local Toolchain

This project follows the user's local toolchain setup:

```bash
source "$HOME/.gvm/environments/default"
eval "$(fnm env --shell bash)"
corepack enable
```

If a fixed Go version is required, source `$HOME/.gvm/environments/go1.25.11` instead, or set `GO_VERSION=go1.25.11` in the build script. If a fixed Node version is required, install the target version with fnm first, or set `NODE_VERSION=v22.22.2` in the build script. Frontend dependency installation and builds must use `yarn`; do not use npm or pnpm on this branch.

## Verification Commands

Backend OBS package verification:

```bash
GOCACHE=/private/tmp/cloudreve-gocache \
GOMODCACHE=/private/tmp/cloudreve-gomodcache \
go test ./pkg/filemanager/driver/obs
```

Frontend asset build verification:

```bash
cd assets
yarn install --network-timeout 1000000
yarn run build
```

Note: `yarn run build-prod` runs `tsc` first. The current `v4.17.0` codebase has many TypeScript errors unrelated to this OBS patch, so that command is not a required gate for this patch. Use the upstream asset build gate, `yarn run build`, when reproducing the image.

## One-Command Image Build and Push

Default command:

```bash
.build/build-and-push-obs-callback-image.sh
```

By default, it builds and pushes the following Linux amd64 image:

```text
registry.extscreen.com/xiaoyou/cloudreve:v4.17.0-obs-callback.1
```

The script supports overriding parameters with environment variables:

```bash
IMAGE=registry.extscreen.com/xiaoyou/cloudreve:v4.17.0-obs-callback.2 \
VERSION=v4.17.0 \
PLATFORM=linux/amd64 \
GO_VERSION=go1.25.11 \
NODE_VERSION=v22.22.2 \
.build/build-and-push-obs-callback-image.sh
```

The script performs these steps:

1. Initializes the gvm environment and switches to `GO_VERSION` if it is set.
2. Initializes the fnm environment and switches to `NODE_VERSION` if it is set.
3. Runs `yarn install --network-timeout 1000000` in `assets/`.
4. Runs `yarn run build` in `assets/`.
5. Writes `assets/build/version.json` with the same version as the backend.
6. Repackages `application/statics/assets.zip`.
7. Builds the Linux amd64 `cloudreve` binary.
8. Uses Docker buildx to build and `--push` the image.

## Manual Build Steps

For troubleshooting, run the steps below manually.

First build and package static assets:

```bash
cd assets
yarn install --network-timeout 1000000
yarn run build
cd ..
printf '{"name":"cloudreve-frontend","version":"v4.17.0"}' > assets/build/version.json
zip -qr - assets/build > application/statics/assets.zip
```

Then build the Linux amd64 backend binary:

```bash
VERSION=v4.17.0
COMMIT="$(git rev-parse --short HEAD)"

CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
  -ldflags "-s -w -X github.com/cloudreve/Cloudreve/v4/application/constants.BackendVersion=${VERSION} -X github.com/cloudreve/Cloudreve/v4/application/constants.LastCommit=${COMMIT}" \
  -o cloudreve
```

Finally build and push the image:

```bash
docker buildx build \
  --platform=linux/amd64 \
  --provenance=false \
  -t registry.extscreen.com/xiaoyou/cloudreve:v4.17.0-obs-callback.1 \
  --push \
  .
```

## Upgrade Checklist

When migrating this patch to a later Cloudreve version:

1. Confirm whether upstream OBS upload completion already calls back into Cloudreve after multipart completion.
2. Keep the OBS complete signed URL free of `x-obs-callback`.
3. Confirm that `/callback/obs/{sessionId}/{callbackSecret}` still supports `POST`.
4. Regenerate `application/statics/assets.zip` and make sure the frontend `version.json` matches the backend `BackendVersion`.
5. Run the backend OBS package verification and frontend `yarn run build`.
