# VoxHandoff 技术架构（v2.1：Hermes 人格化语音移动伴侣）

> 基线日期：2026-08-16（v2.1 修订）。旧版"完整 Agent 控制面"架构已归档至
> `spec/archive/2026-08-16-full-agent/ARCHITECTURE.md`，不再作为当前
> 实现基线。

## 1. 架构原则

### 1.0 当前执行变体：Android-first 语音移动伴侣

VoxHandoff v2.1 是 Hermes 的**第三方 voice-first mobile companion**：手机
负责录音、转写确认、聊天、播放、记忆呈现、人格与 SignalCore 视觉；Agent
能力（工具/任务/审批）属于 Hermes。Hermes 对话接口是 v0.1.0 主后端；
Direct LLM 延后为可选。Hermes 语音能力（streaming TTS/barge-in/唤醒词）是
CLI/桌面/消息平台内建体验，**不是第三方 HTTP API**——VoxHandoff 的 STT/TTS
适配层自研保留，作为护城河。

- 本地优先：录音、STT/TTS 配置、凭据和客户端状态尽量留在设备；
- 助手统一：人格、语音和视觉由稳定 `assistantId` 关联；后端是能力端口，
  不是多个 UI 产品；
- 记忆权威单一化：Hermes 是长期人格/工作记忆权威；本地只保留客户端状态
  （UI/视觉/声音/转写缓存/隐私偏好/设备凭据）；
- 身份分离：Assistant、Provider Profile、conversation、request、message、
  TTS segment 使用各自 opaque identity；
- 确认即绑定：确认文本时同时冻结 backend target snapshot；目标变化使确认失效；
- 协议先于框架：领域模型不依赖 Flutter、Hermes SDK 或第三方协议类型；
- 社区优先：官方方案优先，自研只做适配和产品特有语义；
- 可降级：视觉、STT、TTS、网络任一失败不应破坏文字聊天主链路。

v0.1.0 只实现 Android Flutter 客户端的前台能力；iOS/macOS/Windows 后续按
同一顺序适配，Linux 仅作服务端/STT 部署主机。手机不启动 Node、Hermes、
Gateway、本地 PostgreSQL 或 STT sidecar（STT/TTS 由用户同意的远程 provider
或主机侧服务承担）。

## 2. 技术栈

| 层 | 正式选择 | 约束 |
| --- | --- | --- |
| 客户端 | Flutter / Dart | Android/iOS/macOS/Windows 共用页面和领域接口 |
| 客户端状态 | Riverpod stable API | 不使用 experimental persistence 作为业务权威 |
| 录音 | `record` 适配器（Android 走自实现 Kotlin AudioRecord 原生桥） | 权限/设备选择差异显式暴露；PCM 只在前台录音停止后上传 |
| 音频播放 | `media_kit` 适配器 | 只负责播放/停止；不持有业务状态 |
| 安全存储 | `flutter_secure_storage` + 平台复核 | 独立 key 存 token/CA/凭据，普通库只存引用 |
| 视觉 | Flutter widgets/CustomPainter + GLSL fragment shader | Rive 仅辅助微动效；核心视觉有静态回退 |
| 本地数据库 | Drift | schema 版本化、migration、重启/升级测试 |
| 聊天协议 | Hermes 对话接口（chat/completions 或等价，**契约以 S0 spike 结论为准**）；Direct LLM 延后可选 | 严格 bounded I/O、终态互斥、不映射 Agent 语义 |
| STT | 远程 HTTPS provider（faster-whisper 适配）或本地服务 | 版本化契约、显式 consent、token 独立 secure storage |
| TTS | provider-neutral port；Piper/GSV 本地或远程 | 预热/分段/取消；失败降级字幕 |

## 3. 组件边界

```
apps/client（Flutter UI）
├── lib/presentation      SignalCore 视觉、四态交互、设置、草稿确认
├── lib/application       会话/确认/记忆/语音状态机（Riverpod controller）
├── lib/infrastructure    Drift ledger、secure storage、transport、语音桥
└── lib/domain            领域模型（独立于 Flutter/协议类型）

packages/core            领域类型、状态机、确认快照、消息终态（依赖无关）
packages/adapters        Hermes 对话 adapter（主链路）；Direct LLM adapter（延后可选）

services/stt             faster-whisper HTTPS adapter（版本化 /v1 契约，护城河）
services/tts             （可选）Piper/GSV 服务封装或远程 provider 适配

services/gateway         冻结（归档）——不作为 v0.1.0 实现基线
services/node            冻结（归档）——不作为 v0.1.0 实现基线
```

### 3.1 apps/client

- presentation 只观察 application state 并发出显式用户动作；production
  workflow factory 独占安全存储、TLS channel、transport 与 coordinator 的
  组合与关闭；widget test 以离线 factory 替换；
- domain 模型独立于 Flutter 与生成协议类型；UI state 不含 token/私钥/凭据；
- 移动端不获得本地进程启动能力；不启动任何 sidecar；
- 桌面端后续可按架构原则启动用户同意的本地 STT/TTS 服务（非 v0.1.0）。

### 3.2 packages/core 与 packages/adapters

- core 保持依赖无关：AssistantProfile、ProviderProfile、conversation、
  request、message 终态、确认快照、SignalCore 状态机；记忆规则只描述
  "客户端展示缓存"与"Hermes 权威"边界，不在本地复制长期记忆权威；
- adapters 只做协议翻译：Hermes 对话 adapter（主链路）按 Hermes 实际 API
  协商（chat/completions 或等价，契约以 S0 spike 结论为准），不假设能力
  存在；Direct LLM adapter（延后可选）沿用 OpenAI-compatible chat 严格
  bounded、版本化；禁止把聊天流伪造成 Agent 工具/审批/执行事实；
- 旧 Hermes adapter/Gateway 翻译代码归档冻结，不进入 v0.1.0 生产路径。

### 3.3 交互模式组件（Call/Command）

- 两个模式共享同一录音、STT、记忆呈现、人格与 SignalCore 视觉；
- Call Mode：录音停止即发送（轻量回显 + 1 键取消），流式 TTS 分段播报，
  barge-in（用户开口打断 TTS）；streaming TTS/barge-in 由 VoxHandoff 自研
  适配层实现，v0.1.0 允许退化为"分句完成后播报"但必须支持打断；
- Command Mode：显式确认快照绑定目标，完成后播报或手动播报；
- 工作型指令（审批/发布/删除/付款/授权/sudo）即使处于 Call Mode 也必须
  回退到 Command 级确认。

### 3.4 services/stt

- 版本化 HTTPS 契约：`GET /v1/health`、`POST /v1/transcribe`、可选
  `GET /v1/disclosure`；默认 loopback、独立 Bearer token、有界请求、
  TLS 1.2+、无明文/重定向/模型下载；
- 服务端只记录脱敏统计（bytes/rms/threshold），不记录音频正文/文本/token；
- 远程 provider 的 CA 信任根独立保存在 OS secure storage（不依赖 Gateway
  配对），未配对设备也可导入；改变 provider CA 必须重新导入并重做
  readiness/consent 检查。

### 3.5 冻结模块（升级路径）

`services/gateway`、`services/node`、旧 PostgreSQL ledger 与旧 Hermes
Connector 实现已归档冻结。当 Hermes 上游补齐 run 幂等与 approval ID 后，
可将冻结实现作为"深度 Agent 集成"升级路径恢复，但 v0.1.0 不依赖、不引用、
不测试这些模块作为产品主链路。

## 4. 数据流

### 4.1 语音输入（v0.1.0 固定：停止后上传）

1. 用户按住说话/点击录音 → `AndroidAudioCapture` 原生 AudioRecord 采 16 kHz
   PCM（MethodChannel 控制 + EventChannel 推流）；
2. 停止录音后内存 PCM 经 bounded transport 上传到已同意远程 STT；
3. `POST /v1/transcribe` 返回 final transcript（或明确失败，保留文字草稿）；
4. transcript 可编辑、确认（Call Mode 轻量回显/Command Mode 显式确认）；
5. 原始 PCM 在 final/cancel 后立即删除。

（流式 STT 临时字幕是 Call Mode 升级项，不在 v0.1.0 数据流主路径。）

### 4.2 聊天

1. 确认后的文本经 Hermes 对话 adapter 发送（Direct LLM 延后可选）；
2. 流式 delta 实时显示，数据库合并写入；terminal 到达立即写终态；
3. Call Mode 下稳定句子到达即可开始 TTS 分段播报（或分句完成播报）；
   Command Mode 下 `completed` 触发完成式 TTS；
4. TTS 失败/离线降级为字幕，完整回复始终可读。

### 4.3 记忆

- **Hermes 是长期人格/工作记忆权威**（spike 确认接口语义后）；本地只保留
  客户端状态（UI/视觉/声音/转写缓存/隐私偏好/设备凭据）；
- 若 v0.1.0 的 Hermes 接口只支持无状态对话，本地可暂存 conversation 历史
  作为"展示缓存"，标记为非权威，未来迁移到 Hermes 权威；
- 上下文组装受硬预算约束，禁止无界发送全部历史；
- 删除/编辑递增 contextSnapshotRevision 并撤销旧确认。

## 5. 安全边界

- 凭据只存 OS secure storage，普通库只存 opaque 引用；
- Direct LLM/Hermes 对话的 API key 与 token 与 Profile ID 绑定，改变
  origin/auth 不继承旧 key；
- 所有远程连接有效 TLS 或明确固定证书；不提供永久忽略 TLS 错误的普通选项；
- 日志与诊断脱敏，不含可用密钥/认证头/未脱敏秘密；
- 不自动批准任何权限/删除/发布/付款/授权；审批门（如 Hermes 产生）显示
  "需在 Hermes 端处理"；
- 提交状态不明不静默重试；发送前目标离线保留草稿，恢复后重新确认。

## 6. 一致性

- 消息终态互斥且各自持久化：`streaming`/`completed`/`cancelled`/`failed`/
  `incomplete`/`truncated`；
- 事件/请求按 connection/session/request identity 与单调 sequence 拒绝
  过期项；
- 完整回复独立于 STT/摘要/TTS/播放失败；
- 原始录音本地默认，诊断导出脱敏。

## 7. 非功能

- 中档移动设备稳定 60 FPS；减少动态模式停止非必要 ticker；
- 2,000 条手机历史列表虚拟化验证；
- 延迟预算见 `PRODUCT.md` 7.1；
- 每个外部服务独立失败隔离，不导致 app 退出；
- 长 conversation 请求大小受硬预算限制，历史增长不使写入无界增长。
