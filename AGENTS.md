# AGENTS.md

本文件用于指导 AI 在本仓库维护 Cloudreve 项目。具体补丁、发布镜像和版本迁移背景应写入专门的维护文档，不要放在本文件中。

## 仓库结构

- 主仓库：后端 Go 代码、Dockerfile、构建脚本和嵌入式静态资源。
- `assets/`：前端子模块。前端改动必须在子模块内单独查看、暂存和提交，再回到主仓库更新子模块指针。

## 工具链约定

- 后端使用 gvm 管理 Go，默认使用当前 shell 已激活的 Go 版本；如需固定版本，通过构建脚本环境变量指定。
- 前端使用 fnm 管理 Node，默认使用当前 shell 已激活的 Node 版本；如需固定版本，通过构建脚本环境变量指定。
- 前端包管理只使用 `yarn`，不要使用 npm 或 pnpm。
- 不要为了普通前端构建运行 `.build/build-assets.sh`，该脚本会改写 `assets/package.json` 版本号。

## 工作流程

- 修改前先检查主仓库和 `assets/` 子模块的 `git status`，不要覆盖用户已有改动。
- 后端改动优先遵循现有包结构、错误处理和测试风格。
- 前端改动优先遵循 `assets/` 现有组件、API 封装和构建配置。
- 涉及子模块时，始终分别查看主仓库和 `assets/` 的 diff、status、暂存区和提交历史。
- 不要把构建产物、依赖目录或本地二进制作为源码补丁提交。

## 常用验证

后端按改动范围运行相应 Go 测试：

```bash
GOCACHE=/private/tmp/cloudreve-gocache \
GOMODCACHE=/private/tmp/cloudreve-gomodcache \
go test ./pkg/...
```

前端资产构建验证：

```bash
cd assets
yarn install --network-timeout 1000000
yarn run build
```

如果某个验证命令因既有问题失败，应记录失败命令、关键错误和与当前改动的关系，不要扩大补丁范围去修复无关问题。

## 静态资源与镜像

- `application/statics/assets.zip` 必须由 `assets/build` 重新打包。
- `assets/build/version.json` 的版本必须与后端 `BackendVersion` 一致。
- 根目录 `cloudreve` 二进制、`assets/build`、`assets/node_modules` 不应作为源码补丁提交。
- Docker 构建使用 `buildx`。目标平台和镜像标签应以具体维护文档或用户指令为准。

## 提交注意事项

- 主仓库和 `assets/` 子模块需要分别提交。
- 若修改了 `assets/`，先在子模块提交前端改动，再在主仓库暂存更新后的子模块指针。
- 提交前运行 `git diff --check --cached`；涉及子模块时，主仓库和子模块都要检查。
- 提交说明应描述实际行为变化，避免写入临时调试信息或只适用于个人环境的细节。
