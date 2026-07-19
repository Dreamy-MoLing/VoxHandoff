# Agent Talk 技术架构

## 1. 架构原则

- 本地优先：录音、默认 STT、TTS 播放和离线历史尽量留在设备；
- 事实唯一：PostgreSQL 决定同步模式的耐久状态，Agent 原生线程决定执行上下文；
- 实时与耐久分离：gRPC 负责低延迟事件，数据库同步负责完整历史；
- 安全失败：状态未知时停止重试并显示 `uncertain`；
- 协议先于框架：领域模型不依赖 Flutter、PowerSync、Codex 或 Hermes SDK 类型；
- 社区优先：官方方案优先，其次选择成熟组件，自研只做适配和产品特有语义；
- 可降级：视觉、STT、TTS、同步任一失败不应破坏文字 Agent 主链路。

## 2. 技术栈

| 层 | 正式选择 | 约束 |
| --- | --- | --- |
| 五端客户端 | Flutter / Dart | Windows、Linux、macOS、iOS、Android 共用页面和领域接口 |
| 客户端状态 | Riverpod stable API | 不使用 experimental persistence 作为业务权威 |
| 录音 | `record` 适配器 | 五端能力实测；权限和设备选择差异显式暴露 |
| 音频播放 | `media_kit` 适配器 | 只负责播放/停止；不得持有业务状态 |
| 安全存储 | `flutter_secure_storage` + 平台复核 | Linux 打包 libsecret；Windows/macOS/iOS/Android 做真实读回和迁移测试 |
| 视觉 | Flutter widgets/CustomPainter + GLSL fragment shader | Rive 仅作辅助微动效，核心视觉有静态回退 |
| 本地数据 | PowerSync SQLite + Drift adapter | Drift 桥接仍为 beta，隔离并做契约测试 |
| 领域核心/Node/Gateway | TypeScript + Node.js 22 LTS 基线 | strict 模式；外部 payload 从 `unknown` 校验 |
| 公共协议 | Protocol Buffers + Buf | 从单一 schema 生成 Dart/TypeScript；执行 breaking check |
| 实时传输 | gRPC bidirectional streaming | HTTP/2 + TLS；Client/Node 均主动连接 Gateway |
| 权威存储 | PostgreSQL | 事务、outbox、事件序号、权限和审计 |
| 跨端同步 | PowerSync Open Edition | 服务端 FSL 许可需发布前复核；位于 Sync Adapter 后 |
| 本地 STT | Python sidecar | 优先成熟 Whisper 系后端；以版本化 stdio/loopback 契约替换 |
| TTS | GPT-SoVITS HTTP adapter | 支持其他 TTS；不把模型生命周期写进 Client |
| 多实例消息总线 | NATS JetStream（达到门槛后） | 首版 PostgreSQL outbox 足够，不自研队列 |

第三方版本由 lockfile 固定。升级前检查许可证、平台覆盖、breaking changes、离线语义和安全公告。

## 3. 系统拓扑

```text
Windows / Linux / macOS / iOS / Android
┌──────────────── Flutter Client ────────────────┐
│ UI + Riverpod + local audio + local STT/TTS    │
│ PowerSync SQLite/Drift + secure credential ref │
└───────────┬──────────────────────┬──────────────┘
            │ gRPC live stream     │ durable sync
            │ HTTPS control        │
            ▼                      ▼
┌──────────────── Agent Talk Gateway ─────────────┐
│ auth/pairing  capability  router  event ledger  │
│ control lease  idempotency  outbox  diagnostics │
└───────────┬──────────────────────┬───────────────┘
            │                      │
            ▼                      ▼
       PostgreSQL            PowerSync Service
            ▲
            │ outbound gRPC node stream
┌───────────┴─────────────────────────────────────┐
│ Node Connector + Agent adapters                 │
│ Codex stdio | Hermes HTTPS/SSE/stdio | OpenClaw │
└─────────────────────────────────────────────────┘
```

Embedded 桌面模式可以把 Gateway 和 Node 打包为本地 sidecar，通过 stdio 与 Flutter host 通信，不监听固定入站端口。同步模式必须使用持续在线 Gateway；移动端永不启动本地 Agent 进程。

### 3.1 部署模式与耐久权威

| 模式 | 命令/事件权威 | Client 读模型 | 认证边界 | 远程设备 |
| --- | --- | --- | --- | --- |
| Embedded standalone | bundled sidecar 的应用私有 SQLite 账本 | Client 本地 SQLite | Flutter desktop host 启动的专用 stdio；每次启动完成一次随机 challenge 握手 | 不支持 |
| Self-hosted | Gateway PostgreSQL | PowerSync/Drift 或 cursor-sync SQLite | 设备密钥、短期 access token、scope、TLS | 支持 |
| Hybrid | Self-hosted Gateway PostgreSQL | 同 Self-hosted | 同 Self-hosted；每个请求额外固定 `nodeId` | 支持 |

Embedded SQLite 必须实现与 PostgreSQL 路径相同的 request ID、idempotency uniqueness、conversation sequence、accepted 事务和恢复语义；区别只在存储与传输，不在领域行为。sidecar 在同一事务写入 request、`request.accepted` 和本地 dispatch outbox，提交后才能驱动 Agent。Flutter Client 自身的 SQLite 仍只是读模型和草稿库，不能充当执行账本。

Embedded host 与 sidecar 只使用父进程创建的私有 stdio。sidecar 启动后先交换一次性随机 challenge 和协议版本，握手完成前拒绝业务帧；challenge 不写入命令行、日志或持久配置。若用户要从手机或另一台电脑访问，必须显式将部署提升为 Self-hosted，完成 Gateway 配对和数据迁移，不能临时开放 Embedded sidecar 的未认证端口。

## 4. 代码和进程边界

### 4.1 Flutter Client

负责：

- 页面、可访问性、动画和用户输入；
- 麦克风、音频播放、本地 STT/TTS 调度；
- gRPC live stream 与 HTTPS 配对；
- PowerSync/Drift 本地读取、草稿和低风险元数据 outbox UX；
- OS 安全存储、通知和平台入口。

不得：

- 执行任意 shell 或访问任意文件；
- 保存 Gateway/Agent 管理员密钥；
- 直接解释 Agent 原生 JSON；
- 把 Riverpod 状态当作耐久事实。

### 4.2 Agent Core

纯领域层负责：

- capability、统一事件、错误分类；
- request/session/connection 身份；
- 单调 sequence 与过期事件丢弃；
- 请求和语音状态机；
- 确定性短播报与脱敏规则。

不得依赖数据库、网络、Flutter、PowerSync 或具体 Agent SDK。

### 4.3 Gateway

负责：

- 设备配对、身份验证和 scope；
- 会话账本、请求幂等和事件序号；
- Client/Node 流管理与请求路由；
- control lease、多设备接管和审计；
- PostgreSQL 事务/outbox；
- PowerSync 授权视图和下载权限。

Gateway 需要看到请求明文才能驱动 Agent，因此首版不宣称端到端加密。

### 4.4 Node Connector

部署在 Agent 所在主机，主动出站连接 Gateway。它：

- 使用官方本地/远程协议驱动 Agent；
- 将原生事件严格转换为统一 Protobuf；
- 保留 Agent 原有审批和沙箱；
- 报告实际主机、版本和 capability；
- 不开放 Codex app-server 公网端口。

### 4.5 STT/TTS sidecar

以版本化接口提供 `health`、`capabilities`、`warmup`、`transcribe/synthesize`、`cancel` 和指标。模型崩溃只能影响语音域，不得退出 Gateway 或丢失消息。

## 5. 协议

### 5.1 传输

- Client/Node ↔ Gateway live：gRPC bidirectional streaming；
- 配对、登录、健康和配置：HTTPS；大附件 HTTPS 路径仅为当前禁用的协议扩展点；
- Desktop host ↔ bundled sidecar：JSON-RPC 2.0 over stdio/JSONL；
- Node ↔ Codex：app-server stdio；
- Node ↔ Hermes：HTTPS/SSE，或同机 TUI Gateway 协议；
- Adapter ↔ OpenClaw：Gateway WSS；
- Client durable sync：PowerSync → local SQLite。

WebRTC 不进入默认主链路，因为不持续上传原始音频。未来远程流式音频必须作为独立 media channel，不混入 Agent event stream。

### 5.2 Envelope

公共 schema 至少表达：

```proto
message ProtocolVersion {
  uint32 major = 1;
  uint32 minor = 2;
}

message Envelope {
  ProtocolVersion protocol = 1;
  string event_id = 2;
  string connection_id = 3;
  string device_id = 4;
  string conversation_id = 5;
  string request_id = 6;
  uint64 sequence = 7;
  google.protobuf.Timestamp occurred_at = 8;
  oneof body {
    Handshake handshake = 10;
    ClientCommand command = 20;
    AgentEvent event = 21;
    Ack ack = 22;
    Heartbeat heartbeat = 23;
  }
}
```

规则：

- `sequence` 在 conversation 内由 Gateway 严格递增；
- Client command 另带客户端生成的 opaque `requestId`、`commandId` 和 `idempotencyKey`；即使 acceptance proof 在断线中丢失，Client 仍能按已知 request identity 查询状态而不重新执行；
- Gateway 先事务持久化，后广播 `request.accepted`；
- Client 以 event ID 去重、以 sequence 检测缺口；
- 未知字段可忽略，缺少必需 capability 必须拒绝并报告；
- Protobuf 字段号永久保留，删除字段进入 `reserved`；
- Adapter 原始 payload 只保留在受限诊断中，不作为 UI 协议。
- handshake 完成前只接受 handshake、heartbeat 和明确的协议错误，拒绝业务命令。

### 5.3 Capability

握手至少协商：

- stream/history/session create-resume；
- interrupt/clarification/approval/tool events；
- attachment 与大小限制（M0-M5 必须协商为不支持）；
- idempotency/replay/sequence recovery；
- append-only delta 或可修订 delta；
- Agent、adapter、protocol 版本；
- 实际执行主机和可用 scope。

UI 由 capability 决定功能是否出现，不通过失败探测能力。

### 5.4 版本协商与滚动升级

Handshake 必须携带：当前 protocol major/minor、可接受的 minor 范围、schema build/hash、组件版本、组件角色和 capability revision。规则如下：

- major 不同直接拒绝连接，并返回双方版本和可行动的升级提示；
- 同一 major 内选择双方共同支持的最高 minor；当前 release 必须兼容当前和前一个 minor；
- 新增字段保持 optional/可忽略，删除字段永久 `reserved`；未知事件不能映射成成功或失败，必须以 `unsupported_event` 保留关联并提示升级；
- capability revision 在请求接受时快照并绑定 request；处理中 capability 变化不追溯修改已接受请求；
- Gateway 数据 migration 先兼容旧二进制，再部署 Gateway、Node、Client，最后清理旧字段；任一步失败都允许回退到上一个应用版本而不回滚已提交 migration；
- Buf breaking check、生成物一致性和前一个 minor 的 fixture replay 属于合并门；不能只测试最新组件全套同版本组合。

### 5.5 统一 taxonomy

Agent adapter 只输出以下规范事件；未知原生事件记录为受限诊断或 `unsupported_event`，不得把原生 payload 直接泄漏到 Core/UI：

| 事件组 | 规范类型 | 语义 |
| --- | --- | --- |
| Connection | `connection.ready`、`connection.lost` | 连接状态；lost 不自行推导远端是否执行 |
| Request progress | `request.accepted`、`agent.working`、`request.interrupting` | 已耐久接受、真实工作事件、等待中断确认 |
| Message | `message.delta`、`message.completed` | 可追加/可修订规则由 capability 决定 |
| Tool | `tool.started`、`tool.completed`、`tool.failed` | 只含规范名称、阶段和安全摘要 |
| Approval | `approval.required`、`approval.resolved`、`approval.expired`、`approval.cancelled` | 与耐久 approval 状态机一致 |
| Clarification | `clarification.required`、`clarification.resolved`、`clarification.expired`、`clarification.cancelled` | 不与 approval scope 混用 |
| Request terminal | `request.completed`、`request.failed`、`request.cancelled`、`request.interrupted` | 四种不可互换的终态 |

每个事件必须有本地生成的 opaque `eventId`、connection/session/request identity、从 1 开始且连续的规范 sequence 和本地接收 `occurredAt`。原生 sequence/time 可以放入受限诊断，但不能直接驱动 Core；`final` 由规范终态类型推导，不接受上游布尔值。

Capability 字段固定为：`deltaMode`（`none|append_only|revisable`）、`eventStream`、`sessionHistory`、`createSession`、`resumeSession`、`interrupt`、`steer`、`clarification`、`approval`、`toolEvents`、`attachments`、`idempotency`、`replay`、`sequenceRecovery`、请求大小和 timeout。M0-M5 `attachments=false`；UI 不使用旧名称或失败探测能力。

错误至少包含 `stage`、`category`、稳定 `code`、用户可行动的安全 `message` 和 `retryable`。stage 固定为 `recording|stt|connection|authentication|authorization|protocol|agent|summary|tts|playback|storage|sync|configuration`；category 固定为 `validation|unavailable|authentication|authorization|protocol|timeout|rate_limit|upstream|storage|privacy|unknown`。只有能证明幂等且 acceptance 未发生的操作才允许标记自动安全重试；当前 Client 不自动重试 executable command。

## 6. 状态机

### 6.1 请求生命周期

```text
draft
  → recording → transcribing → awaiting_confirmation
  → command_sent → request_accepted
  → agent_working ↔ waiting_approval | waiting_clarification
  → message_completed → request_completed
```

任一阶段可进入与语义匹配的 `cancelled`、`failed` 或 `uncertain`。取消不是失败；`command_sent` 后连接丢失且无法证明是否接受时必须进入 `uncertain`。

### 6.2 三种停止

- `recording.cancel`：丢弃未发送录音/转写；
- `speech.stop`：停止客户端 TTS，Agent 继续；
- `request.interrupt`：请求 Agent 停止，等待其确认。

三者不能共用按钮语义或内部状态。用户开口默认触发 `speech.stop`。

### 6.3 Delta 与 TTS

只有适配器声明 delta 为 append-only，且句子已稳定、通过安全过滤时，才允许边生成边播报。可修订 delta 必须等待 `message.completed`。审批、部分完成和 uncertain 永远不能提前播报为成功。

### 6.4 审批与澄清状态机

每个 approval 必须绑定 opaque approval/request/conversation/agent/node ID、原生审批 ID、操作摘要 hash、所需 scope、创建时间和 Agent 提供的 expiry。状态只允许：

```text
pending → approved | rejected | expired | cancelled
```

终态不可更改。响应事务必须同时校验当前 control lease、`approve` scope、device identity、操作摘要 hash 和 approval 仍为 pending，再以 compare-and-set 写入终态和审计事件。相同 device/idempotency key 的重试返回原结果；其他并发或迟到响应返回 `approval_already_resolved`，不得转发给 Agent。

Gateway/Client 重启或重连时从耐久账本恢复 pending approval。Agent 原始超时到达、请求结束或 Agent 明确撤回时写入 `expired`/`cancelled`；网络断开、lease 到期、TTS/语音事件和 UI 消失都不能产生批准。澄清可以提交文字，但仍绑定 request 和控制设备，不复用 approval 的 `approve` 权限。

## 7. 数据架构

### 7.1 权威关系

- PostgreSQL：同步部署的会话、消息、事件、设备和权限权威；
- Agent thread/session：Agent 执行上下文权威；
- Client SQLite：本地可查询副本和未提交草稿；
- gRPC delta：短期实时表现，不是唯一耐久副本；
- Riverpod：页面派生状态，不是持久层。

### 7.2 逻辑表

- `users`、`devices`、`device_credentials`、`device_scopes`；
- `gateways`、`nodes`、`agents`、`agent_capabilities`；
- `conversations`、`turns`、`messages`、`message_revisions`；
- `events`：event ID、conversation sequence、type、脱敏 payload；
- `requests`：command/idempotency/acceptance/final state；
- `approvals`、`clarifications`；
- `device_cursors`、`control_leases`；
- `gateway_dispatch_outbox`：已接受 request 到固定 Node 的耐久投递；
- `gateway_event_outbox`：已提交事件到实时流/同步层的耐久投递；
- `attachments`：仅保留未来扩展的 hash、metadata、encrypted object reference；M0-M5 capability 固定为 false；
- `stage_metrics`、`diagnostic_events`。

原始录音和合成音频不进入这些同步表。

### 7.3 事务与恢复

接收命令的事务同时：

1. 校验设备、scope、lease 和 idempotency；
2. 创建/查找 request；
3. 分配 conversation sequence；
4. 写入 `request.accepted` event；
5. 写入 Gateway outbox；
6. 提交后才向 Client 返回 accepted。

重连时 Client 发送每个活跃 conversation 的 `lastAckSequence`。Gateway 在短期窗口续传；游标过旧或存在缺口时，Client 先以 PowerSync 本地快照收敛，再订阅最新事件。未知请求只按 request ID 查询，绝不自动复制提交。

Client 离线时只能保存草稿和明确列入 allowlist 的低风险元数据变更。可执行 Agent command 不进入自动排空的 Client outbox；用户点击发送但尚未建立可认证 live stream 时仍保持草稿并显示“未发送”。写出 command 后连接中断且未收到耐久 acceptance proof 时进入 `uncertain`，重连只执行 `GetRequest(requestId)` 或 replay，不重新调用 Send。

### 7.4 多设备冲突

会话消息只追加，不做 CRDT。每个 conversation 使用 30 秒 control lease，控制设备至多每 10 秒续租；另一设备必须通过带 revision 的 compare-and-set 显式接管。lease 过期或被接管后，旧设备的新 send/interrupt/approval 命令以 `control_lease_lost` 拒绝，已运行 Agent 请求不受影响。标题和标签等低风险元数据用 revision 乐观锁。一个 Agent 会话默认串行请求。

路由只使用 opaque `nodeId`、`agentId` 和原生 session identity。Gateway 在 acceptance 事务内固定这些值及 capability revision；显示名变化不影响路由。接受前目标离线可以失败，接受后不得自动改投另一 Node/Agent。只有适配器能证明同一原生执行上下文可恢复时才续传，否则进入明确失败或 `uncertain`。

### 7.5 数据分类、保留与删除

持久数据至少标记为 `content`、`security_audit`、`diagnostic_metadata`、`secret_reference` 或 `ephemeral_media`。日志管线只接受脱敏后的 diagnostic metadata；正文、原始 Agent payload 和音频不能因异常对象序列化而落入普通日志。

- 原始录音、provisional 音频和 TTS 缓存只在录制/播放设备按 `PRODUCT.md` 默认期限保存；
- 原始 STT transcript 是 local-only content，不通过 PowerSync 或 Gateway event payload 同步；
- 同步消息删除先提交 tombstone 和 content access revocation，再异步清理活动数据库与对象存储；
- security audit 可以保留 opaque ID、动作类型和结果，但删除正文后不得保留可还原正文的 payload/hash 组合；
- 部署配置必须公开活动数据、诊断和备份各自保留期限；恢复备份后必须重新应用 tombstone、凭据吊销和设备撤销记录。

## 8. 同步方案及退出路径

PowerSync Open Edition 提供 PostgreSQL 到五端 SQLite 的 local-first 同步。采用条件：

- Client SDK 的 Apache-2.0 许可可接受；
- Service 的 FSL 源码可用许可通过正式发布复核；
- 自托管运行、升级、备份和监控通过运维测试；
- beta `drift_sqlite_async` 通过通知、离线写、重连和 schema 升级契约测试。

PowerSync 类型和 schema 只存在于 Sync Adapter。若许可、稳定性或运维不合格，切换为 PostgreSQL + gRPC cursor sync + Drift/SQLite；公共 Protobuf、领域模型和 UI 不变。

## 9. Agent 适配

### 9.1 Codex

- 本地启动 `codex app-server`，stdio initialize；
- 支持 thread start/resume、turn start/interrupt、delta、完成和审批；
- 从已安装 CLI 临时生成 schema 并执行协议兼容检查；
- 不提交大批版本特定生成物；
- 进程创建位于可 fake 的 adapter 边界；server request 只输出规范 ID、method 和脱敏安全摘要，notification 只输出 method，二者都不向 Core/UI 暴露原生 params；
- WebSocket 实验传输不直接对公网开放；
- 不依赖 Codex Desktop 当前窗口或焦点会话。

### 9.2 Hermes

- 普通路径使用 HTTPS/SSE；
- 映射 health、capability、session、run、stop、approval 和错误；
- run、stop 和 approval command 都携带调用方可稳定复用的 idempotency key；adapter 重建后由 run/request identity 恢复，不自行重复提交；
- SSE 单事件默认上限 256 KiB，畸形 JSON 使当前 stream 明确失败；非 2xx 响应正文不进入普通异常或日志；
- 需要完整控制时在 Hermes 同机侧使用正式 TUI Gateway 协议；
- 启动用户既有 gateway 前必须确认不会意外连接其消息平台；
- 远程明文 HTTP 默认拒绝，loopback 开发例外必须显式配置。

### 9.3 OpenClaw

- 使用原生 Gateway WSS、role/scope、设备身份和配对；
- 适配器保存可撤销设备身份，不默认请求管理员 scope；
- 事件缺口刷新权威状态，不假设永久回放；
- Agent Talk Client 不直接接触 OpenClaw 管理密钥。

## 10. 语音架构

### 10.1 录音

Flutter `record` 位于 AudioCapture adapter 后。统一输出 PCM/WAV 或 STT 明确接受的流格式；采样率、声道和设备能力由运行时探测，不硬编码跨平台等价。

### 10.2 STT

本地 Python sidecar 和远程 STT 共同实现：

- capability/health/warmup；
- start/push/end/cancel；
- provisional/final transcript；
- language、timing、confidence（若后端可用）；
- 分阶段指标和无音频错误。

本地 STT 是默认路径。远程 STT adapter 只有在用户完成 provider 级显式同意后才能接收音频，并必须报告目标 origin、TLS 验证状态、是否流式上传及已知服务端保留策略；这些信息变化时暂停上传并要求重新确认。远程 STT 音频不得复用 Agent/Gateway 管理凭据。

首轮测试集至少 30 条中文技术请求，覆盖中英混合、路径、版本号、噪声和自我修正。

### 10.3 TTS 与播放

GPT-SoVITS adapter 生成规范音频块，`media_kit` adapter 播放。TTS 队列使用稳定 segment identity；最多预生成少量片段，停止后释放旧请求。完整回复、播报文本、音频缓存是三个独立数据域。

## 11. 视觉架构

- `ThemeExtension`/普通 Dart token：颜色、间距、圆角、线宽、排版、状态语义和动效时长；业务 widget 不直接散布常量；
- Widget/CustomPainter：布局、文字、交互、静态核心和可访问性；
- GLSL fragment shader：核心能量场、扫描线、噪声、色差和音频波纹；
- Rive：按钮、连接图标等非核心矢量微动效；
- Platform plugins：麦克风会话、安全存储、全局快捷键、通知和窗口行为。

设计系统组件以独立 catalog/use case 覆盖真实状态，再进入业务页面；catalog 工具、第三方组件库和 styling package 都只能是开发或表现层依赖，不得成为领域状态权威。优先使用 Flutter 内建语义、focus、Theme 和自有小组件；只有组件隔离测试或跨端一致性收益足以抵消依赖/迁移成本时才引入社区包。

shader 只接收 `audioLevel`、`statePhase`、`errorPulse` 等归一化数值，不接收领域对象。所有状态必须有无动画等价表现；减少动态时禁用扫描、故障和持续波纹，只保留静态几何、文字和高对比状态标记。

## 12. 网络与安全

### 12.1 远程访问

优先顺序：Tailscale/WireGuard 私有组网 → SSH 隧道 → HTTPS/gRPC TLS 反向代理。Gateway/Node 默认最小监听，Agent 本地接口绑定 loopback。

### 12.2 身份与权限

- 设备生成密钥对，配对后获得可撤销凭据；
- scope 至少分 `observe`、`send`、`interrupt`、`approve`、`administer`；
- 审批响应包含 approval/request/device/host identity 和签名；
- control lease 不能替代高风险审批 scope；
- 令牌只存 OS 安全存储，数据库保存引用或不可逆标识。

当前一个 Gateway 只有一个 owner。首次 owner bootstrap 只能在 Gateway 本机交互控制台、Embedded 私有 stdio 或部署时显式提供的一次性恢复流程完成，不能通过未认证公网请求创建。后续配对流程为：

1. Gateway 生成最长 10 分钟、单次使用并限速的 pairing challenge；
2. 新设备生成本地密钥对并提交公钥、challenge 和所请求 scope；
3. 已授权 `administer` 设备或本机控制台同时显示并核对 Gateway/设备 fingerprint、实际 Gateway 地址和 scope；
4. Gateway 校验 proof-of-possession 后签发绑定 audience、device ID、公钥和 scope 的凭据，并消费 challenge；
5. 新设备通过签名 challenge 完成读回测试，配对才显示成功。

普通 access token 最长 15 分钟；可续期设备凭据最长 30 天并在使用时轮换。Gateway 在每次建流、续期和高风险命令时检查设备/凭据撤销状态；撤销后关闭现有流并使 refresh 失效。恢复 owner 必须通过本机显式流程并撤销旧 owner 凭据，不能依赖邮件、显示名或可猜测共享秘密。所有 pairing、scope 变更、轮换、失败和撤销写入无正文安全审计。

配对 wire contract 固定为 `Begin → Inspect/Approve → Complete → Confirm`：`Begin` 只产生短期 challenge 和待核对事实，不产生可用 token；`Inspect/Approve` 仅允许已验证的 `administer` 设备或等价本机私有入口；`Complete` 校验新设备对 Gateway 给出的 domain-separated payload 的 Ed25519 签名并生成待确认凭据；`Confirm` 再校验绑定 audience、device、credential、scope 的独立签名 payload，成功后才原子激活凭据并返回 token。早期 schema 中的 `CompletePairing.device_proof`、`CompletePairingResponse.access_token/refresh_token` 只为 wire 兼容保留，服务端不得把它们作为 proof 或提前签发通道。

公钥只接受规范 Ed25519 SPKI DER，fingerprint 为规范公钥或 TLS 证书的 SHA-256；challenge、nonce、access token 和 refresh token 使用 CSPRNG。数据库只保存 bearer token 的 SHA-256 标识，不保存明文；日志、审计和错误不得包含 challenge、nonce、签名、公钥原文或 token。刷新事务必须锁定当前 credential generation，成功时同时废止旧 refresh、轮换 access/refresh 并递增 generation；已轮换 refresh 的再次出现视为重放并撤销该 credential family，而不是普通重试。可重复网络响应只能通过明确的短时加密/内存结果缓存实现，不能重新激活旧 token。

设备签名统一使用协议中标明的 domain、固定字段次序和长度前缀字节编码；签名 payload 由 Gateway 返回或由共享 helper 构造，禁止签署含糊 JSON、显示名或客户端自报地址。`ResolveApproval`、远程配对授权、scope 变更和撤销必须同时满足 bearer scope、实时撤销检查、单次 nonce 与设备签名；签名不能替代 control lease，也不能使 pending/expired/resolved 状态回退。

### 12.3 TLS 与秘密

- 公网 TLS 证书必须验证；
- 自签名证书要求显式导入或指纹固定；
- 禁止普通设置永久忽略证书错误；
- 日志在结构化写入前递归脱敏；
- 诊断导出默认不含正文，可由用户预览并选择加入脱敏样本。

### 12.4 故障语义

- 配对 unary RPC 每个用户动作只发起一次；Gateway 用 `agent-talk-error-code` trailer 携带白名单领域错误码，Client 不解析或展示远端原始 message。只有明确的领域/状态拒绝可进入 failed/待批准，传输超时、断线、取消、未知状态或调用后本地异常均进入 `uncertain`，必须由用户显式恢复并复用已经持久化的同一请求/签名；
- gRPC 故障：停止 live delta，以耐久快照恢复；
- PowerSync 故障：本地历史可读，live 事件标记等待持久化；
- Gateway/耐久账本（PostgreSQL 或 Embedded SQLite）故障：草稿保留，未确认命令不发送；
- Agent 故障：完整已接收文字保留，request 进入明确失败或 uncertain；
- STT/TTS/视觉故障：退化为文字交互。

## 13. 延后组件

- Socket.IO：默认 at-most-once，不能替代事件账本和数据库同步；
- NATS JetStream：多 Gateway/worker、outbox 瓶颈或独立审计流水线出现后采用；
- Matrix：聊天同步成熟，但对 Agent 高频事件、审批和主机语义过重；
- LiveKit/WebRTC：未来持续远程音频或多人旁听时独立引入；
- Automerge/Yjs：未来多人协作编辑 prompt 时再采用；
- Rust/wgpu：Flutter shader 经实测无法满足性能时再作为独立渲染器评估。

## 14. 选型依据

以下资料是 2026-07-18 基线的复核入口；依赖升级时重新检查，不把链接当作永久兼容保证：

- [Flutter 支持平台](https://docs.flutter.dev/reference/supported-platforms)
- [record 平台能力矩阵](https://pub.dev/packages/record)
- [media_kit](https://github.com/media-kit/media-kit)
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)
- [Riverpod](https://pub.dev/packages/riverpod)
- [gRPC Dart basics](https://grpc.io/docs/languages/dart/basics/)
- [Buf 文档](https://buf.build/docs/)
- [PowerSync Flutter SDK](https://docs.powersync.com/client-sdks/reference/flutter/)
- [PowerSync Drift 集成](https://docs.powersync.com/client-sdks/orms/flutter-orm-support)
- [PowerSync 项目与许可证说明](https://github.com/powersync-ja)
- [Codex App Server](https://developers.openai.com/codex/app-server/)
- [Hermes Programmatic Integration](https://hermes-agent.nousresearch.com/docs/developer-guide/programmatic-integration)
- [OpenClaw Gateway Protocol](https://docs.openclaw.ai/gateway/protocol)

## 15. 仓库级威胁模型

### 15.1 关键资产与攻击者

关键资产包括：Agent 执行/中断/审批权限；设备私钥和可续期凭据；Agent/STT/TTS token；请求与实际 Agent/Node/原生会话的绑定；用户确认文本、完整回复、审批记录、音频和 transcript；acceptance、sequence、idempotency、lease、revocation、tombstone 和审计事实。

必须假设以下输入不可信，即使连接已认证：

- Agent 的 JSON-RPC/SSE/WSS、stdout/stderr、delta、tool/approval 摘要、原生 ID、时间和 sequence；
- Client/Gateway/Node 的网络帧、重放 token、配对 challenge、ack、游标、旧 schema 和离线副本；
- STT transcript、TTS 文本/音频、模型生成 Markdown/链接/控制字符；
- operator 配置的 URL、代理、TLS、自定义 executable/model path；
- dependency、生成协议、CI action、migration、安装包和更新制品。

当前假设单 owner 控制 Gateway/OS/数据库/备份并保护本机控制台。root/管理员 OS 已完全失陷超出保密保证，但实现仍不得扩大 secret 的持久化与传播。Agent sandbox、OS secure storage、TLS 和签名包是外部信任基础；已认证 Agent/语音服务只证明身份，不证明返回内容安全。

### 15.2 信任边界

| 边界 | 主要威胁 | 必需控制 |
| --- | --- | --- |
| 用户意图 → STT/final transcript | 误识别、目标变化、直接发送绕过确认 | 默认确认；直发按设备/Agent关闭；目标变化重置；审批仍独立 |
| Flutter host → Embedded sidecar | 假 sidecar、帧注入、账本分叉 | 私有 stdio、一次性 challenge、版本握手、sidecar 耐久账本 |
| Client → Gateway | 未认证、scope 越权、重放、旧 lease | TLS、设备密钥、短 token、逐命令 scope/lease、idempotency |
| Gateway → PostgreSQL/Sync | 越权同步、删除复活、撤销失效 | 权威事务、最小同步规则、tombstone、恢复后重放撤销 |
| Gateway → Node | 主机替换、重复投递、静默故障转移 | Node 出站认证、opaque ID、target/capability 固定、耐久 outbox |
| Node → Agent | 恶意/畸形原生事件、审批混淆、无限流 | `unknown` 解析、大小/速率/超时、规范事件、CAS 审批、取消 |
| Client/sidecar → OS | PATH 替换、权限滥用、缓存/密钥泄露 | 规范化受信 executable、最小平台权限、私有目录、安全存储 |
| Client → remote STT/TTS | 未同意上传、目标/TLS 改变、第三方保留 | 默认关闭、provider 同意、origin/TLS/保留展示、凭据隔离 |
| 开发/CI → 发布制品 | 依赖/Action/生成物投毒、签名泄露 | lockfile、最小依赖、固定 CI 权限、SBOM、签名和可重复质量门 |

### 15.3 重点攻击故事与控制

- **重复执行/错主机执行**：重放、重连或 failover 让命令执行两次或改投同名主机。以数据库 uniqueness、acceptance + dispatch outbox 同事务、opaque target、status lookup 代替 resend；任何重复执行为发布阻断。
- **审批混淆**：迟到/并发响应、摘要替换或 approval ID 复用。响应必须绑定 request/Agent/Node/native ID、摘要 hash、device、scope、lease、expiry 和 idempotency，只允许 pending 的 CAS 进入一个终态。
- **事件串线/伪完成**：恶意 sequence、旧 connection、未知事件或可修订 delta 改变当前会话。Core 按 connection/session/request/sequence/terminal state 拒绝；未知事件不得映射为成功；uncertain 不播报完成。
- **secret/正文泄露**：Authorization、URL、stderr、上游错误体、native payload 或诊断导出携带凭据/正文。所有日志在序列化前递归脱敏，普通诊断只存 metadata，raw payload 只进入受限、限时且显式选择的诊断域。
- **本地 executable 替换**：PATH 中伪造 `codex`、`hermes`、Python 或播放器。PoC 可接受开发者显式命令；发行版只能启动 bundled 或显式信任且校验 canonical path、owner 和版本的 executable。
- **资源耗尽**：无限 SSE、巨大帧/错误体、深对象、delta 洪泛或音频队列拖垮进程。每个边界定义 frame/body/depth/rate/queue 上限、deadline、backpressure、cancel 和 supervisor；单域崩溃退化而不丢文字事实。
- **UI/语音欺骗**：Agent 内容伪装成审批框、完成状态或危险链接。trusted chrome 与 untrusted content 分层，清理主动内容和控制字符；安全状态只来自规范事件，TTS 不朗读 uncertain/approval-pending 为成功。
- **供应链/迁移攻击**：恶意 dependency、CI action、schema 或 migration 继承高权限。使用 lockfile、协议生成检查、最小 CI 权限、SBOM/许可证/secret scan、签名制品和 expand-first migration；生产禁止 destructive reset。

### 15.4 严重度校准

| 严重度 | Agent Talk 语境 |
| --- | --- |
| Critical | 未认证/已撤销设备获得 administer/approve；自动批准高风险操作；重放导致重复或错主机执行；公网可达 RCE/管理员凭据泄露 |
| High | observe-only/旧设备可 send/interrupt/approve；跨会话串线影响用户操作；远程 STT 未同意上传；普通日志持久化可用 secret/大量私密正文；协议降级把失败/uncertain 变成功 |
| Medium | 已认证低权限设备或恶意 Agent 造成有界 DoS/崩溃但无执行越权；保留/删除延迟违反已展示策略；单个 sidecar 失败但耐久事实完整 |
| Low | 无实际攻击路径的版本/粗粒度 timing 暴露；仅开发 PoC 的本地不便；不影响可信文字和审批的视觉/TTS 偏差 |

威胁模型在新增网络入口、附件、多用户、公共云、后台音频、Agent 类型、权限 scope、存储权威、更新机制或 trust boundary 时必须先更新。安全扫描发现的新攻击故事应先回写本节和相应验收门，再进入实现修复。
