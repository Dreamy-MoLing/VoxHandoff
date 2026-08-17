# VoxHandoff Companion Bridge

`@agent-talk/bridge` 是 Fedora 主机侧的长期运行安全接入层。它终止 TLS，
管理 QR 配对和 per-device credential，并把手机请求转发到主机配置的 Hermes、
STT、TTS 服务。它不保存 Hermes 上游凭据的明文副本以外的任何手机可见形式，
也不把上游凭据返回给手机。

## 端点契约

所有响应都是 `application/json`，并带 `Cache-Control: no-store`；流式聊天响应
保留上游的 `text/event-stream` 内容类型。

| 方法 | 路径 | 授权 | 成功响应 |
| --- | --- | --- | --- |
| GET | `/healthz` | 无 | `200 {status, component, version}` |
| GET | `/readyz` | 无 | `200` ready 或 `503` not_ready，只有有限状态检查 |
| POST | `/v1/pairing/sessions` | loopback 或 `X-Bridge-Host-Authorization: Bearer ...` | `201` QR 载荷；token 仅出现在此响应/二维码 |
| POST | `/v1/pairing/exchange` | JSON QR token | `200 {pairingRequestId, deviceId, deviceName, deviceFingerprint, challenge, status:"awaiting_confirmation", expiresAt}`；不签发长期凭据 |
| GET | `/v1/pairing/requests` | 主机授权 | `200` 待确认设备名、指纹、6 位码 |
| POST | `/v1/pairing/requests/:id/confirm` | 主机授权 | `200` confirmed |
| GET | `/v1/pairing/requests/:id/status` | `X-Bridge-Pairing-Authorization: Bearer <pairing token>` | `200 {pairingRequestId, status, expiresAt}`；status 为 `awaiting_confirmation` / `confirmed` / `expired` / `cancelled` |
| POST | `/v1/pairing/requests/:id/complete` | `device_signature`（绑定 request id + challenge） | `201 {pairingRequestId, deviceId, credentialId, deviceCredential, scopes, expiresAt}`；credential 只返回一次 |
| POST | `/v1/pairing/sessions/:id/cancel` | 主机授权或 `X-Bridge-Pairing-Authorization: Bearer <pairing token>` | `200 {cancelled:true}` |
| POST | `/v1/pairing/requests/:id/cancel` | 主机授权 | `200 {cancelled:true}` |
| GET | `/v1/devices` | 主机授权 | `200` 设备摘要，不含凭据 |
| POST | `/v1/devices/:id/revoke` | 主机授权 | `200 {revoked:true/false}` |
| POST | `/v1/devices/me/revoke` | `Authorization: Bearer <device credential>` | `200 {revoked:true}`；成功后该 credential 立即失效 |
| GET | `/v1/capabilities` | per-device Bearer | `200` chat/stt/tts/hermes manifest |
| GET | `/v1/pinning` | per-device Bearer | `200` current/backup SPKI pin + generation |
| POST | `/v1/pinning/rotate` | 主机授权 + current pin claim | `200` 新 pin 状态 |
| POST | `/v1/chat/completions` | per-device Bearer + `chat` scope | 受控 Hermes 响应/流 |
| POST | `/v1/stt/transcribe` | per-device Bearer + `stt` scope | 受控 STT 响应 |
| POST | `/v1/tts/synthesize` | per-device Bearer + `tts` scope | 受控 TTS 响应 |
| GET | `/v1/services/{hermes,stt,tts}/health` | 对应 per-device Bearer | 受控上游 readiness 响应 |
| GET | `/v1/services/{hermes,stt,tts}/capabilities` | 对应 per-device Bearer | 配置了 capability path 时透传 |

错误响应为 `{ "error": { "code": "...", "message": "..." } }`。错误消息不含
token、凭据、上游响应正文或内部 URL。

手机配对调用约定：exchange 请求 JSON 使用 `server_id`、`pairing_session_id`、
`pairing_token`、`device_name`、`device_public_key_spki`；status 使用 GET 路径
中的 `pairingRequestId` 和 `X-Bridge-Pairing-Authorization`，不把 token 放进 URL；
complete 请求 JSON 只使用 `device_signature`；手机取消使用 QR 中的
`pairing_session_id` 调用 session cancel。Android Keystore 的 ECDSA P-256
`SHA256withECDSA` 签名与既有 Ed25519 签名都可用于 complete。

## 配置与运行

启动至少需要以下环境变量：

- `VOXHANDOFF_BRIDGE_ENDPOINT`
- `VOXHANDOFF_BRIDGE_TLS_KEY_FILE`
- `VOXHANDOFF_BRIDGE_TLS_CERT_FILE`
- `VOXHANDOFF_BRIDGE_SERVER_ID`
- `VOXHANDOFF_BRIDGE_SPKI_PIN`
- `VOXHANDOFF_BRIDGE_BACKUP_SPKI_PIN`

Hermes 使用 `VOXHANDOFF_BRIDGE_HERMES_URL` 与
`VOXHANDOFF_BRIDGE_HERMES_TOKEN`；STT/TTS 是可选的同形配置。token 只用于
主机到上游的受控请求，不进入 QR、manifest、状态响应或日志。非 loopback 监听
还必须配置至少 32 字符的 `VOXHANDOFF_BRIDGE_HOST_ADMIN_TOKEN`。

状态文件默认位于工作目录下 `.voxhandoff/bridge-state.json`，也可用
`VOXHANDOFF_BRIDGE_STATE_FILE` 指定绝对路径。写入采用临时文件替换，目录/文件
权限分别为 `0700`/`0600`；pairing token、device credential 只保存 SHA-256 hash。

```bash
npm run check -w @agent-talk/bridge
npm run test -w @agent-talk/bridge
npm run start -w @agent-talk/bridge
```

## 安全边界

- pairing token 是 256-bit、3 分钟 TTL；exchange 只可消费一次，消费后 token
  仅可作为同一 session 的手机 status/cancel 身份，不能再次 exchange。过期、
  取消和重新生成 QR 都会使它失效。
- 手机公钥绑定在 pending device 上；只有主机确认设备名/6 位码并验证设备私钥
  签名后才签发长期凭据。
- current/backup 是 SHA-256 SPKI pin。未知 pin fail closed；轮换只能把已有
  backup 提升为 current，并在已认证的当前 pin 通道下写入新的 backup。
- Hermes/STT/TTS 上游地址和凭据均由主机固定配置，客户端不能指定任意 URL。
- 本组件不提供 Agent 状态、任务调度、审批、工具编排、消息数据库或长期聊天
  历史能力。
