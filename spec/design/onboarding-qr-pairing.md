# VoxHandoff 配对式首次配置（Onboarding）实施基线

> 状态：**实施基线（已定稿，2026-08-16）**。本文件是 M6 onboarding 里程碑的
> 实现依据，取代 2026-08-16 初版草案。安全模型经外部评审（RFC 8628 / RFC 9449 /
> Android Keystore / Network Security Config 交叉验证）。
> 未实施前不改变当前 spec/PRODUCT.md 4.1 的配置式流程。

## 1. 目标体验

普通用户第一次打开 VoxHandoff：

```
电脑端（Hermes / VoxHandoff）：
  → 启动 Companion Bridge → 选择 Hermes Profile →「连接手机」→ 显示二维码

手机端：
  → 扫码 → 校验 SPKI pin → 生成 Android Keystore 设备密钥
  → 兑换一次性 pairing token

电脑端：
  →「vivo V2359A 请求连接 · 482731」→ 确认

Bridge：
  → 登记设备公钥 → 签发该设备凭据 → 返回 capability manifest

手机端：
  → Hermes ✓ / 语音识别 ✓ / 声音 Bronya ✓ → 开始通话
```

URL、端口、model、Session ID/Key、证书、API key、STT 地址**都不出现在默认路径**。
只有「高级 → 手动连接」才显示完整表单。

## 2. QR 安全模型（定稿）

### 2.1 Pairing token

| 项目 | 定稿 |
| --- | --- |
| 生成 | 256-bit 随机、一次性 |
| TTL | **3 分钟，最长不超过 5 分钟** |
| 服务端保存 | **只存 token hash**；状态 `pending / consumed / expired / cancelled` |
| 消耗 | **原子一次性消费**；成功、超时、取消、重新生成 QR 都立即作废 |
| 用途 | **只能换取设备身份**，绝不能随后直接充当 API token |

### 2.2 防 QR 重放 / 抢先兑换

- 单靠 token 不够；扫码后手机**生成设备密钥对**，配对绑定该**公钥**；
- **主机端最后一次确认设备**：显示设备名 + 短验证码（如 6 位数字），确认后才签发长期设备凭据；
- 长期凭据：**每台手机独立、可撤销**；绝不复用 Hermes API key。

### 2.3 设备密钥与长期凭据

- 私钥由**手机生成并保存于 Android Keystore**（优先硬件保护 / StrongBox，不可导出）；
- 长期凭据进 Android secure storage；
- 证书突然变化 → **fail closed**，提示"服务器身份发生变化，需要重新配对"；
- model、capabilities、session 等自动发现。

### 2.4 Certificate pin

- 类型：**SHA-256 SPKI pin**（`SubjectPublicKeyInfo`），不保存整个 leaf certificate fingerprint；
- 数量：当前 pin + 一个预生成 **backup pin**（Android Network Security Config 官方建议）；
- 失效：**不设置"到期后自动关闭 pinning"**；密钥异常变化 fail closed；
- 换代：旧 pinned TLS 通道下下发新的 backup pin；两个都丢失才重新配对。

### 2.5 QR 本体（定稿载荷）

```text
protocol_version
bridge_endpoint
server_id
pairing_session_id
spki_pin
pairing_token
expires_at
```

**删除直接 Hermes endpoint 和 profile。** profile 在主机生成 QR 时就绑定到
`pairing_session_id`，手机不需要知道。二维码只是"找到并认证这台 VoxHandoff
Bridge"的启动凭据。

### 2.6 术语修正

默认 QR 流程通过"主机屏幕 → 手机摄像头"**带外传递 pin**，严格说**不是裸 TOFU**。
只有手动输入地址后首次接受未知指纹的 fallback 才叫 TOFU。

## 3. Companion Bridge（定稿：长期薄组件）

**选择长期运行的极薄 `VoxHandoff Companion Bridge`**（一次性 bootstrap 工具不选——
一次性工具最终仍得留下 nginx/socat/TLS terminator 等长期组件，复杂度只是转移）。

### 3.1 职责（严格限定）

```text
TLS termination
QR pairing
设备凭据签发 / 撤销
certificate pin rotation
capability discovery
Hermes / STT / TTS reverse proxy
health/readiness
```

### 3.2 明确禁止（防 Gateway 复辟）

```text
Agent 状态机
conversation 权威
Hermes memory
tool orchestration
approval
任务调度
消息数据库
长期聊天历史
Node/Gateway 语义
```

它是**安全接入层 + 服务路由器**，不能继续长成第二个 Hermes Gateway。

### 3.3 关键收益

**Hermes API key 永远只存在 Fedora 主机上。** 手机只拿 Companion Bridge 的
per-device credential。手机丢失只 revoke 这一台设备，不需要轮换 Hermes 总密钥。

## 4. 连接方式定位（按用户类型）

| 方式 | 定位 |
| --- | --- |
| 二维码 + certificate pin | **默认推荐路径** |
| Tailscale | 已在用 Tailscale 的用户可选"快捷路径" |
| 公网 HTTPS / Cloudflare Tunnel | 高级远程部署 |
| URL + API Key + CA | 专家手动配置（= 手动连接 fallback，此路径才有裸 TOFU） |

产品不绑定 Tailscale，也不强迫用户学证书。

## 5. Capability Manifest（配对后下发，不塞进 QR）

扫码成功后，由 Bridge 通过**已认证的连接**返回：

```json
{
  "chat": { "available": true },
  "stt": { "available": true, "capabilities": { } },
  "tts": { "available": true, "voices": [ ], "recommended_voice": "Bronya" },
  "hermes": { "profile": "...", "model": "...", "capabilities": { } }
}
```

手机默认只连接**一个 Bridge origin + 一套 pin + 一个设备身份**：

```text
Phone ──(pinned HTTPS)──► VoxHandoff Companion Bridge
                              ├── Hermes
                              ├── STT
                              └── TTS
```

STT/TTS provider token、CA、真实内部 URL、GPT-SoVITS reference path 等全部留在主机。
用户要手机直接连 Cloud STT/TTS → 「高级 → 自定义语音服务」作为第二个独立 trust domain。

**配对成功不必强制 STT/TTS 全部存在**：
- Hermes Chat：必须可用
- STT 缺失：显示"语音输入未配置"
- TTS 缺失：文字正常工作
- 有 STT/TTS：自动启用电话式完整体验

## 6. 现有代码对接点（已核实）

- `HermesChatHttpTransport` 允许注入 HttpClient → 可注入 pinning 逻辑；
- 凭据与配置已分离存储（`hermes_conversation_secret_store.dart`）；
- `isSafe` 已把 HTTPS/路径/origin 限制封装在 domain 层；
- Android release 已关闭 cleartext、只信任系统根 → 底线保留；
- 视觉状态机对齐 Hermes 主链路（M5-SIG）是前置。

## 7. 待实施项（M6 范围）

1. 主机侧 Companion Bridge 组件（命名避免与冻结 Gateway 混淆）；
2. QR 扫描（mobile_scanner / zxing 等）+ 最小权限；
3. Android Keystore 设备密钥生成 + secure storage 凭据；
4. SPKI pin 校验 + backup pin 轮换；
5. Capability Manifest 解析与 UI（状态总览 + 高级折叠）；
6. 「高级 → 手动连接」fallback（保留现有表单 + 裸 TOFU）；
7. spec/PRODUCT.md 4.1 首次配置章节重写为配对流程；
8. 安全测试：token 重放/过期/取消、pin 更换 fail-closed、设备撤销。
