# VoxHandoff 决策记录（DECISIONS）

> 本文件是当前基线（2026-08-16 定稿）的活跃决策记录通道。历史决策
> D-001~D-036 归档于 `spec/archive/2026-08-16-full-agent/DECISIONS.md`，
> 仅作升级路径参考；D-037/D-038 由归档交付记录（archive DELIVERY 0.1.4）
> 摘录补登，可溯源。新增决策继续编号（D-039 起），格式沿用旧版。

## D-039：M6 onboarding 定稿——QR + certificate pin + Companion Bridge

- 日期：2026-08-17
- 状态：设计定稿，实施中（四路并行 2026-08-17 启动）
- 依据：`spec/design/onboarding-qr-pairing.md`（安全模型经 RFC 8628 /
  RFC 9449 / Android Keystore / Network Security Config 交叉评审）
- 决策：v0.1.0 首次配置采用配对式 onboarding：手机扫码（QR 载荷含
  `protocol_version/bridge_endpoint/server_id/pairing_session_id/spki_pin/
  pairing_token/expires_at`）→ 生成 Android Keystore 设备密钥（私钥不可
  导出）→ SPKI pin 校验（当前 pin + backup pin，异常 fail closed）→
  兑换一次性 pairing token（服务端只存 hash、3 分钟 TTL、原子消费，只能
  换取设备身份）→ 主机端最后一次确认（设备名 + 6 位短验证码）→ 签发每台
  设备独立可撤销的长期凭据。新增长期薄组件「Companion Bridge」作为安全
  接入层 + 服务路由器（TLS termination / QR pairing / 凭据签发撤销 /
  certificate pin rotation / capability discovery / Hermes-STT-TTS
  reverse proxy / health），明确禁止 Agent 状态机、conversation 权威、
  Hermes memory、tool orchestration、approval、任务调度、消息数据库等
  Gateway 语义（不能长成第二个 Gateway）。Hermes API key 只存在主机。
- 边界：未实施前不改变 `spec/PRODUCT.md` 4.1 的配置式流程；产品不绑定
  Tailscale；远程 STT/TTS provider token、CA、真实内部 URL 留在主机。

## D-038：远程 STT CA 信任根修复与真机语音闭环（自 archive DELIVERY 0.1.4 补登）

- 日期：2026-08-16
- 状态：Fixed and verified on device（Codex 提交 `241ded1`/`ba0f702`）
- 决策：readiness 失败根因是 secure storage 旧 CA 与当前 STT 证书链不匹配
  导致 TLS 握手失败。新增 `SecureRemoteSttTrustedRootCertificateStore`，
  远程 STT CA 用独立 OS secure-storage key 保存，不再与 Gateway 配对
  profile 共享；未配对设备也可导入，改变 provider CA 必须重新导入并重做
  readiness/consent 检查。

## D-037：STT token 回读链路修复（自 archive DELIVERY 0.1.4 补登）

- 日期：2026-08-16
- 状态：Fixed（Codex 提交 `d2b0a22`）
- 决策：`VoiceProviderSettingsController.saveRemoteStt` 原先在空 token 时
  立即失败返回，导致同 provider ID 从安全存储回读已有 token 的分支不可达；
  修复移除该错误早退（1 行），保留"空 token 回读、回读仍空才拒绝保存"的
  既有安全逻辑。

## 摘录：近期语音链路决策（原文见 archive DECISIONS.md）

- **D-032**：原生 PCM 事件流必须等待 EventChannel sink 就绪（2026-08-14）
- **D-034**：Android AudioRecord 采用 VOICE_RECOGNITION + READ_BLOCKING
  作为 native 组合（2026-08-14）
- **D-035**：服务端单帧上限导致长录音空音频，分块修复后真机转写闭环打通
  （2026-08-14，Fixed and verified on device）
- **D-036**：STT 配置门槛简化客户端接入完成（Fetch disclosure）
  （2026-08-14，Implemented locally / 真机验证待做）
