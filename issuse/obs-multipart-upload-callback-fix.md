# OBS 分片上传完成回调修复

## 问题描述

OBS 分片上传完成阶段，前端显示错误：

```text
Cannot read properties of undefined (reading 'innerHTML')
```

该错误是前端解析失败响应时产生的二次异常，不是真正的失败点。

实际失败发生在 `obsFinishUpload(...)` 请求 OBS complete multipart upload URL 时。
旧流程在 complete URL 中携带 `x-obs-callback`，OBS 合并分片时同步触发回调；当回调连接失败时，OBS complete 请求返回非 200，例如：

```text
Connect to 127.0.0.1:39999 [/127.0.0.1] failed: Connection refused (Connection refused)
```

随后前端将该错误响应按 S3/OSS XML 解析并读取 `<Message>`，但响应内容不包含该节点，最终显示为 `innerHTML` 读取失败。

## 后端修复

提交：`1c029cf fix(obs): 修复OBS分片上传回调问题，改用客户端主动回调`

后端修改文件：

- `pkg/filemanager/driver/obs/obs.go`

实际变更：

- 删除 OBS 完成分片上传签名 URL 中的 `x-obs-callback` 查询参数。
- 删除 OBS 服务端回调策略的生成和编码逻辑。
- 不再由 OBS complete multipart upload 请求触发 Cloudreve 回调。

## 前端修复

提交：`c323079 feat(uploader): 新增OBS上传完成回调流程`

前端修改文件：

- `src/api/api.ts`
- `src/component/Uploader/core/api/index.ts`
- `src/component/Uploader/core/uploader/obs.ts`

实际变更：

- 新增 `sendObsCompleteUpload(sessionId, sessionKey)`，向 `/callback/obs/{sessionId}/{sessionKey}` 发起 `POST` 请求。
- 新增 `obsUploadCallback(sessionID, sessionKey)` 封装 OBS 上传完成回调。
- 调整 OBS `afterUpload()`：先完成 OBS multipart upload，再主动调用 Cloudreve 回调接口。

## 修复后的行为

OBS 分片上传完成流程调整为：

1. 前端上传所有分片。
2. 前端调用 OBS complete multipart upload URL 完成 OBS 侧合并。
3. 前端调用 Cloudreve `/callback/obs/{sessionId}/{sessionKey}` 接口。
4. Cloudreve 完成上传会话并创建文件记录。
