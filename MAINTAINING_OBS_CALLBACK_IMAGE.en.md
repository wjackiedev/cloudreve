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

## Upgrade Checklist

When migrating this patch to a later Cloudreve version:

1. Confirm whether upstream OBS upload completion already calls back into Cloudreve after multipart completion.
2. Keep the OBS complete signed URL free of `x-obs-callback`.
3. Confirm that `/callback/obs/{sessionId}/{callbackSecret}` still supports `POST`.
4. Run the backend OBS package verification and frontend `yarn run build`.
