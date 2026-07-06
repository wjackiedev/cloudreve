# Cloudreve v4.17.0 OBS Callback 镜像维护文档

本分支基于 Cloudreve `v4.17.0`，只维护一个较窄的 OBS multipart 上传回调修复。

## 补丁范围

- 后端：`pkg/filemanager/driver/obs/obs.go`
  - 不再把 `x-obs-callback` 附加到 OBS `CompleteMultipartUpload` signed URL。
  - 保留 Cloudreve 原有上传会话信息和 multipart 完成流程。
- 前端子模块：`assets`
  - 先完成 OBS multipart upload。
  - 然后由前端主动调用 Cloudreve 回调接口：
    `POST /callback/obs/{sessionId}/{callbackSecret}`。

这样可以避免依赖 OBS 从对象存储侧回调 Cloudreve，同时仍然让 Cloudreve 在客户端完成 multipart upload 后正确结束上传会话。

## 本地工具链

本项目按用户本机工具链管理：

```bash
source "$HOME/.gvm/environments/default"
eval "$(fnm env --shell bash)"
corepack enable
```

如果需要固定 Go 版本，可以改为 source `$HOME/.gvm/environments/go1.25.11`，或在构建脚本中设置 `GO_VERSION=go1.25.11`。如果需要固定 Node 版本，可以先用 fnm 安装对应版本，或在构建脚本中设置 `NODE_VERSION=v22.22.2`。前端依赖和构建统一使用 `yarn`，不要在本分支使用 npm 或 pnpm。

## 验证命令

后端 OBS 包验证：

```bash
GOCACHE=/private/tmp/cloudreve-gocache \
GOMODCACHE=/private/tmp/cloudreve-gomodcache \
go test ./pkg/filemanager/driver/obs
```

前端资产构建验证：

```bash
cd assets
yarn install --network-timeout 1000000
yarn run build
```

注意：`yarn run build-prod` 会先执行 `tsc`。当前 `v4.17.0` 代码库里存在大量与本 OBS 补丁无关的 TypeScript 错误，因此该命令不是本补丁的必过门禁。复现镜像时使用上游资产构建门禁 `yarn run build`。

## 一键构建并推送镜像

默认命令：

```bash
.build/build-and-push-obs-callback-image.sh
```

默认会构建并推送以下 Linux amd64 镜像：

```text
registry.extscreen.com/xiaoyou/cloudreve:v4.17.0-obs-callback.1
```

脚本支持用环境变量覆盖参数：

```bash
IMAGE=registry.extscreen.com/xiaoyou/cloudreve:v4.17.0-obs-callback.2 \
VERSION=v4.17.0 \
PLATFORM=linux/amd64 \
GO_VERSION=go1.25.11 \
NODE_VERSION=v22.22.2 \
.build/build-and-push-obs-callback-image.sh
```

脚本会执行以下步骤：

1. 初始化 gvm 环境；如设置了 `GO_VERSION`，则切换到该 Go 版本。
2. 初始化 fnm 环境；如设置了 `NODE_VERSION`，则切换到该 Node 版本。
3. 在 `assets/` 中执行 `yarn install --network-timeout 1000000`。
4. 在 `assets/` 中执行 `yarn run build`。
5. 将 `assets/build/version.json` 写成与后端一致的版本。
6. 重新打包 `application/statics/assets.zip`。
7. 编译 Linux amd64 的 `cloudreve` 二进制。
8. 使用 Docker buildx 构建并 `--push` 镜像。

## 手动构建步骤

排障时可以按下面步骤手动执行。

先构建并打包静态资源：

```bash
cd assets
yarn install --network-timeout 1000000
yarn run build
cd ..
printf '{"name":"cloudreve-frontend","version":"v4.17.0"}' > assets/build/version.json
zip -qr - assets/build > application/statics/assets.zip
```

再编译 Linux amd64 后端二进制：

```bash
VERSION=v4.17.0
COMMIT="$(git rev-parse --short HEAD)"

CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
  -ldflags "-s -w -X github.com/cloudreve/Cloudreve/v4/application/constants.BackendVersion=${VERSION} -X github.com/cloudreve/Cloudreve/v4/application/constants.LastCommit=${COMMIT}" \
  -o cloudreve
```

最后构建并推送镜像：

```bash
docker buildx build \
  --platform=linux/amd64 \
  --provenance=false \
  -t registry.extscreen.com/xiaoyou/cloudreve:v4.17.0-obs-callback.1 \
  --push \
  .
```

## 升级检查清单

将本补丁迁移到后续 Cloudreve 版本时：

1. 先确认上游 OBS 上传完成逻辑是否已经在 multipart 完成后调用 Cloudreve。
2. 保持 OBS complete signed URL 不包含 `x-obs-callback`。
3. 确认 `/callback/obs/{sessionId}/{callbackSecret}` 仍支持 `POST`。
4. 重新生成 `application/statics/assets.zip`，并确保前端 `version.json` 与后端 `BackendVersion` 一致。
5. 跑后端 OBS 包验证和前端 `yarn run build`。
