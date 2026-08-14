# VoxHandoff 技术架构

## 1. 架构原则

### 1.0 当前执行变体：Android-first

本轮只实现 Android Flutter 客户端的前台能力。Android 通过认证的远程
Gateway 访问 Hermes 工作链路，或直接访问用户配置的 Direct LLM；手机不
启动 Node、Hermes、Gateway、本地 PostgreSQL 或 STT sidecar。桌面 sidecar、
iOS、后台监听、唤醒词和全双工实时媒体保持既有架构定义，但不属于当前
实现批次。

- 本地优先：录音、STT/TTS 配置、LLM API key 和离线历史尽量留在设备；
- 助手统一：人格、记忆、语音和视觉由稳定 `assistantId` 关联，聊天/工作 backend 是能力端口，不是两个 UI 产品；
- 身份分离：Assistant、Provider Profile、configuration revision、conversation、request、message 和 TTS segment 使用各自 opaque identity；
- 事实唯一：PostgreSQL 决定同步模式的耐久状态，Agent 原生线程决定执行上下文；
- 实时与耐久分离：gRPC 负责低延迟事件，数据库同步负责完整历史；
- 安全失败：状态未知时停止重试并显示 `uncertain`；
- 确认即绑定：确认文本时同时冻结 backend target snapshot；目标变化使确认失效；
- 协议先于框架：领域模型不依赖 Flutter、PowerSync 或 Hermes SDK 类型；
- 社区优先：官方方案优先，其次选择成熟组件，自研只做适配和产品特有语义；
- 可降级：视觉、STT、TTS、同步任一失败不应破坏文字聊天主链路。

当前 Android 语音输入使用既有 `ConsentedRemoteSttPort` 的 HTTPS 变体：精确
origin、TLS policy、retention disclosure、provider revision 和 consent timestamp
属于配置；provider token 单独存入 OS-backed secure storage；PCM 只在前台录音停止
后以内存批量上传。没有明确同意、token 或安全 origin 时 fail closed，STT 失败不得
覆盖可编辑文字草稿。

## 2. 技术栈

| 层 | 正式选择 | 约束 |
| --- | --- | --- |
| 五端客户端 | Flutter / Dart | Windows、Linux、macOS、iOS、Android 共用页面和领域接口 |
| 客户端状态 | Riverpod stable API | 不使用 experimental persistence 作为业务权威 |
| 录音 | `record` 适配器 | 五端能力实测；权限和设备选择差异显式暴露 |
| 音频播放 | `media_kit` 适配器 | 只负责播放/停止；不得持有业务状态 |
| 安全存储 | `flutter_secure_storage` + 平台复核 | Linux 打包 libsecret；Windows/macOS/iOS/Android 做真实读回和迁移测试 |
| 视觉 | Flutter widgets/CustomPainter + GLSL fragment shader | Rive 仅作辅助微动效，核心视觉有静态回退 |
| 本地数据 | Drift 2.34.2 + path_provider 2.1.6 + SQLite 3.5.0 | 完整事件与 conversation cursor 同事务提交；uint64 使用规范定宽十进制 TEXT，SDK 隔离在 storage adapter |
| 领域核心/Node/Gateway | TypeScript + Node.js 22 LTS 基线 | strict 模式；外部 payload 从 `unknown` 校验 |
| 公共协议 | Protocol Buffers + Buf | 从单一 schema 生成 Dart/TypeScript；执行 breaking check |
| 实时传输 | gRPC bidirectional streaming | HTTP/2 + TLS；Client/Node 均主动连接 Gateway |
| 权威存储 | PostgreSQL | 事务、outbox、事件序号、权限和审计 |
| 跨端同步 | Gateway gRPC cursor sync | 复用现有认证、replay、Ack 和 PostgreSQL 权威；PowerSync 保留为通过独立许可/运维 gate 后的可选 Sync Adapter |
| STT port | stdio/loopback/remote adapter | 默认预设为应用拥有路径的 versioned faster-whisper sidecar；设置页只启用/探测 readiness，不接受命令或管理模型生命周期 |
| TTS port | loopback/remote adapter | 默认预设为用户自装的 Piper HTTP 服务；精确 loopback `/info` 探测与 `/synthesize` WAV，GPT-SoVITS 等可替换，不把模型生命周期写进 Client |
| 自接 LLM API | 本机直接 HTTPS adapter | 小型 OpenAI-compatible chat-completions 端口；key 仅进 OS 安全存储，不经过 Gateway |
| 多实例消息总线 | NATS JetStream（达到门槛后） | 首版 PostgreSQL outbox 足够，不自研队列 |

第三方版本由 lockfile 固定。升级前检查许可证、平台覆盖、breaking changes、离线语义和安全公告。

## 3. 系统拓扑

```text
Windows / Linux / macOS / iOS / Android
┌──────────────────── Flutter Client ────────────────────┐
│ AssistantProfile + conversation UI + SignalCore       │
│ target confirmation + local audio/STT/TTS + lifecycle │
│ Drift local history/read model + secure credential ref│
└──────────────┬──────────────────────────┬───────────────┘
               │                          │ direct HTTPS/SSE
               │                          ▼
               │                 User LLM Provider Profile
               │                 pure chat; no Agent semantics
               │
               │ authenticated gRPC live + cursor sync
               │ HTTPS pairing/control
               ▼
┌──────────────── VoxHandoff Gateway ─────────────┐
│ auth/pairing  capability  router  event ledger  │
│ control lease  idempotency  outbox  diagnostics │
└───────────┬──────────────────────┬───────────────┘
            │
            ▼
       PostgreSQL
            ▲
            │ outbound gRPC node stream
┌───────────┴─────────────────────────────────────┐
│ Hermes Node Connector                           │
│ capability gate + HTTPS/SSE + session state     │
└─────────────────────────────────────────────────┘
```

Direct LLM、STT/TTS 与本地记忆都通过明确 Profile/Port 进入 Assistant 层，不经过 Gateway，也不获得 Agent capability。Embedded 桌面模式可以把 Gateway 和 Node 打包为本地 sidecar，通过 stdio 与 Flutter host 通信，不监听固定入站端口。同步模式必须使用持续在线 Gateway；移动端永不启动本地 Agent 进程。

### 3.1 部署模式与耐久权威

| 模式 | 命令/事件权威 | Client 读模型 | 认证边界 | 远程设备 |
| --- | --- | --- | --- | --- |
| Embedded standalone | bundled sidecar 的应用私有 SQLite 账本 | Client 本地 SQLite | Flutter desktop host 启动的专用 stdio；每次启动完成一次随机 challenge 握手 | 不支持 |
| Self-hosted | Gateway PostgreSQL | Drift/SQLite + cursor sync；可选 PowerSync adapter | 设备密钥、短期 access token、scope、TLS | 支持 |
| Multi-device self-hosted | Self-hosted Gateway PostgreSQL | 同 Self-hosted | 同 Self-hosted；每个请求固定 `nodeId` 与 Hermes session | 支持 |

Embedded SQLite 必须实现与 PostgreSQL 路径相同的 request ID、idempotency uniqueness、conversation sequence、accepted 事务和恢复语义；区别只在存储与传输，不在领域行为。sidecar 在同一事务写入 request、`request.accepted` 和本地 dispatch outbox，提交后才能驱动 Agent。Flutter Client 自身的 SQLite 仍只是读模型和草稿库，不能充当执行账本。

Embedded host 与 sidecar 只使用父进程创建的私有 stdio。sidecar 启动后先交换一次性随机 challenge 和协议版本，握手完成前拒绝业务帧；challenge 不写入命令行、日志或持久配置。若用户要从手机或另一台电脑访问，必须显式将部署提升为 Self-hosted，完成 Gateway 配对和数据迁移，不能临时开放 Embedded sidecar 的未认证端口。

## 4. 代码和进程边界

### 4.1 统一 Assistant 层

Assistant 层是产品语义组合点，不是新的远程服务。它包含：

- `AssistantProfile`：稳定 `assistantId`、名称/人格、系统提示、记忆策略、语音/视觉/交互 Profile 引用、默认聊天和 Hermes 工作 backend 引用；
- `Conversation`：稳定 `conversationId`，固定 `assistantId`、backend kind、backend target snapshot 和上下文策略；
- `ConfirmedDraft`：文本 revision/hash 与确认时的 `TargetSnapshot`；
- capability projection：把 Direct LLM 的 chat-only 和 Hermes 的真实 capability 投影到同一 UI，但不合并权限语义；
- backend handoff：需要从聊天进入 Hermes 工作时，生成新的可预览确认，不自动转发历史或记忆。

AssistantProfile 拥有单调 `assistantRevision`；名称、人格、system prompt 或影响请求/交互的策略变化都递增它。AssistantProfile 只保存普通设置和 opaque reference。Provider key、Gateway token、设备私钥与 Hermes credential 保留在各自安全边界；Assistant 层不得读取或序列化秘密正文。

### 4.2 Flutter Client

负责：

- 页面、可访问性、动画和用户输入；
- 麦克风、音频播放、本地 STT/TTS 调度；
- Assistant/Profile、conversation、确认目标和本地 Direct LLM request lifecycle；
- gRPC live stream 与 HTTPS 配对；
- Drift/SQLite 本地读取、草稿和低风险元数据 outbox UX；
- OS 安全存储、通知和平台入口。

不得：

- 执行任意 shell 或访问任意文件；
- 保存 Gateway/Agent 管理员密钥；
- 直接解释 Agent 原生 JSON；
- 把 Riverpod 状态当作耐久事实。

### 4.3 Agent Core

纯领域层负责：

- capability、统一事件、错误分类；
- request/session/connection 身份；
- 单调 sequence 与过期事件丢弃；
- 请求和语音状态机；
- 确定性短播报与脱敏规则。

不得依赖数据库、网络、Flutter、PowerSync 或具体 Agent SDK。

### 4.4 Gateway

负责：

- 设备配对、身份验证和 scope；
- 会话账本、请求幂等和事件序号；
- Client/Node 流管理与请求路由；
- control lease、多设备接管和审计；
- PostgreSQL 事务/outbox；
- 已认证 cursor-sync 查询与最小授权；若启用可选 PowerSync adapter，再负责其授权视图和下载规则。

Gateway 需要看到请求明文才能驱动 Agent，因此首版不宣称端到端加密。

### 4.5 Node Connector

部署在 Agent 所在主机，主动出站连接 Gateway。它：

- 只使用显式配置的 Hermes HTTPS/SSE endpoint 驱动 Agent；
- 将原生事件严格转换为统一 Protobuf；
- 保留 Agent 原有审批和沙箱；
- 报告实际主机、版本和 capability；
- 不开放 Hermes endpoint 入站公网端口；
- 将 Hermes credential 仅从环境变量读入内存，URL、状态文件和日志均不得包含 token；
- 以权限收紧的本地状态文件保存 conversation 到 Hermes session 的映射，不保存正文或 secret。

### 4.6 STT/TTS sidecar

以版本化接口提供 `health`、`capabilities`、`warmup`、`transcribe/synthesize`、`cancel` 和指标。模型崩溃只能影响语音域，不得退出 Gateway 或丢失消息。

## 5. 协议

### 5.1 传输

- Client/Node ↔ Gateway live：gRPC bidirectional streaming；
- 配对、登录、健康和配置：HTTPS；大附件 HTTPS 路径仅为当前禁用的协议扩展点；
- Flutter desktop host ↔ embedded Gateway/Node bundled sidecar：JSON-RPC 2.0 over stdio/JSONL；
- Flutter STT port ↔ `voxhandoff-stt`：versioned protocol 1.0 envelope over stdio/JSONL；它不是 JSON-RPC，不得复用 Gateway/Node framing；
- Node ↔ Hermes：HTTPS/SSE；明文 HTTP 仅允许显式配置的字面量 loopback；
- Client durable sync：Gateway cursor replay/status → Drift local SQLite；可选 PowerSync 只替代历史快照传输。

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
- attachment 与大小限制（当前 MVP 必须协商为不支持）；
- idempotency/replay/sequence recovery；
- append-only delta 或可修订 delta；
- Agent、adapter、protocol 版本；
- 实际执行主机和可用 scope。

UI 由 capability 决定功能是否出现，不通过失败探测能力。

### 5.4 版本协商与滚动升级

VoxHandoff 是产品与仓库品牌。既有 `agent_talk.v1` protobuf package、`agent-talk/*` 签名 domain、`@agent-talk/*` package scope、存储键和平台 application ID 是已经进入持久数据或跨组件契约的兼容标识，不随展示品牌改名；未来只有带明确 wire/data migration、双读窗口和回滚证据的独立变更才能替换。

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

每个事件必须有本地生成的 opaque `eventId`、connection/session/request identity、从 1 开始且连续的规范 sequence 和 UTC `occurredAt`。Hermes 提供有效数字 Unix timestamp 时适配器规范化为 UTC；缺失或非法时使用确定性本地序号时间，不能以每次重连的墙钟时间破坏事件身份。原生 sequence 只经范围和单调校验后进入规范序号空间；`final` 由规范终态类型推导，不接受上游布尔值。

Capability 字段固定为：`deltaMode`（`none|append_only|revisable`）、`eventStream`、`sessionHistory`、`createSession`、`resumeSession`、`interrupt`、`steer`、`clarification`、`approval`、`toolEvents`、`attachments`、`idempotency`、`replay`、`sequenceRecovery`、请求大小和 timeout。当前 MVP `attachments=false`；UI 不使用旧名称或失败探测能力。

Hermes capability 必须保守协商：缺失、未知或类型错误一律解释为不支持。`append_only` 只有在 Hermes 同时明确声明 streaming 与 append-only delta 时成立；`sequenceRecovery` 还要求稳定事件 ID，`replay`、approval、interrupt、session create/resume 和 idempotency 均不得由版本号或成功探测推断。Connector 注册前至少要求 `eventStream=true` 与 `idempotency=true`，否则拒绝上线并报告 capability stage。

错误至少包含 `stage`、`category`、稳定 `code`、用户可行动的安全 `message` 和 `retryable`。stage 固定为 `recording|stt|connection|authentication|authorization|protocol|agent|summary|tts|playback|storage|sync|configuration`；category 固定为 `validation|unavailable|authentication|authorization|protocol|timeout|rate_limit|upstream|storage|privacy|unknown`。只有能证明幂等且 acceptance 未发生的操作才允许标记自动安全重试；当前 Client 不自动重试 executable command。

## 6. 状态机

### 6.1 草稿确认与目标快照

草稿状态不能只保存 `text + confirmed`。领域对象至少为：

```text
ConfirmedDraft {
  draftId, draftRevision, confirmedText, textHash,
  assistantId, assistantRevision,
  contextSnapshotRevision, contextSnapshotHash,
  chatSource, conversationId,
  targetSnapshot, confirmedAt
}
```

`confirmedText` 是确认时规范化后的不可变正文，`textHash` 用于完整性比对而不是正文查找；`contextSnapshotHash` 绑定实际 assembled prior context。Direct target snapshot 固定 `providerProfileId + credentialRevision + configurationRevision + normalizedOrigin + model`；Hermes target snapshot 固定 `conversationId + nodeId + agentId + capabilityRevision + sessionId`。当前协议以 `nodeId` 表示安全意义上的执行主机 identity，单独的主机显示名不参与安全比较。ChatSource、Assistant/Profile/credential/config/context revision/hash、conversation、Agent、Node、capability 或 session 任一变化都原子清除确认并回到 `editing`；发送 API 只接受 `ConfirmedDraft` 并从中读取正文和目标，不得在发送时重新读取全局当前值。

### 6.2 Hermes 请求生命周期

```text
draft
  → recording → transcribing → awaiting_confirmation
  → command_sent → request_accepted
  → agent_working ↔ waiting_approval | waiting_clarification
  → message_completed → request_completed
```

任一阶段可进入与语义匹配的 `cancelled`、`failed` 或 `uncertain`。取消不是失败；`command_sent` 后连接丢失且无法证明是否接受时必须进入 `uncertain`。

### 6.3 Direct LLM 请求与消息生命周期

每个 Direct request 由一个 request-scoped owner 持有：Profile snapshot、conversation、HTTP request handle、assistant message、persistence coalescer 和可选 TTS generation。连接测试使用独立 owner/transport，不得覆盖聊天 request handle。

```text
ready → streaming → completed
                  ↘ cancelled | failed | incomplete | truncated
```

- 只有观察到 adapter 的明确完成事实才进入 `completed`；当前 OpenAI-compatible SSE 要求 `[DONE]`；
- 除显式取消和主动超限外，任何没有完成证明的异常终止都按是否已有有效 assistant 正文分类：已有正文的 EOF、timeout、network 或后续 protocol parse error 进入 `incomplete`；尚无正文的连接、TLS、HTTP、timeout、network 或 protocol error 进入 `failed`；响应大小硬限制进入 `truncated`，请求前发现上下文超预算则直接拒绝发送；用户或生命周期取消进入 `cancelled`；
- 所有终态保留已收到文本并立即持久化；非 completed 回复不触发完成式 TTS、滚动摘要或默认后续上下文；
- 切换 source/Profile/conversation、修改活动配置或销毁 owner 时采用 cancel-and-wait 后切换，或阻止切换；旧 generation 不能写新 state/history/TTS；
- transport close、chat cancel、connection test cancel、TTS generation cancel 和 playback stop 具有不同 identity，不共享一个无归属的 `_active` 指针。

### 6.4 三种停止

- `recording.cancel`：丢弃未发送录音/转写；
- `speech.stop`：停止客户端 TTS，Agent 继续；
- `request.interrupt`：请求 Agent 停止，等待其确认。

三者不能共用按钮语义或内部状态。用户开口默认触发 `speech.stop`。

### 6.5 Delta 与 TTS

只有适配器声明 delta 为 append-only，且句子已稳定、通过安全过滤时，才允许边生成边播报。可修订 delta 必须等待 `message.completed`。审批、部分完成和 uncertain 永远不能提前播报为成功。

### 6.6 审批与澄清状态机

每个 approval 必须绑定 opaque approval/request/conversation/agent/node ID、原生审批 ID、操作摘要 hash、所需 scope、创建时间和 Agent 提供的 expiry。状态只允许：

```text
pending → approved | rejected | expired | cancelled
```

终态不可更改。响应事务必须同时校验当前 control lease、`approve` scope、device identity、操作摘要 hash 和 approval 仍为 pending，再以 compare-and-set 写入终态和审计事件。相同 device/idempotency key 的重试返回原结果；其他并发或迟到响应返回 `approval_already_resolved`，不得转发给 Agent。

Gateway/Client 重启或重连时从耐久账本恢复 pending approval。Agent 原始超时到达、请求结束或 Agent 明确撤回时写入 `expired`/`cancelled`；网络断开、lease 到期、TTS/语音事件和 UI 消失都不能产生批准。澄清可以提交文字，但仍绑定 request 和控制设备，不复用 approval 的 `approve` 权限。

## 7. 数据架构

### 7.1 权威关系

- Assistant/Profile ordinary configuration：当前设备本地配置库；每条记录有 opaque ID 与单调 revision；
- Provider/Gateway credentials：OS 安全存储；普通配置只保存 credential reference；
- Direct conversation、消息终态与本地记忆：Client SQLite，以 `conversationId`/`assistantId` 为边界；
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
- `attachments`：仅保留未来扩展的 hash、metadata、encrypted object reference；当前 MVP capability 固定为 false；
- `stage_metrics`、`diagnostic_events`。

原始录音和合成音频不进入这些同步表。

Client 本地逻辑表至少分离：

- `assistant_profiles` 与 revision：人格、系统提示、策略和各 Profile 引用；
- `provider_profiles` 与 revision：provider kind、规范 origin、auth realm、credential slot/revision、模型/能力配置；
- `local_conversations`：assistant、backend kind、target snapshot、context policy；
- `local_messages`：role、assembled content、互斥 terminal、provenance/context eligibility、revision 与时间；
- `pinned_memories`：正文、来源、backend 可见范围、创建/更新时间；
- `rolling_summaries`：conversation、覆盖到的 message revision、摘要正文与生成策略版本。

禁止继续用一个 `providerId` 同时充当配置身份、凭据索引、conversation、历史分区和 TTS conversation identity。

### 7.3 事务与恢复

接收命令的事务同时：

1. 校验设备、scope、lease 和 idempotency；
2. 创建/查找 request；
3. 分配 conversation sequence；
4. 写入 `request.accepted` event；
5. 写入 Gateway outbox；
6. 提交后才向 Client 返回 accepted。

重连时 Client 从 Drift 读取每个已跟踪 conversation 的耐久 cursor；尚无 cursor 的已跟踪 conversation 从 0 开始，以 1-500 条的有界 replay 分页追赶 PostgreSQL 事件，再与 live 事件串行收敛。每个 replay 响应必须以关联原 command、conversation、起止 sequence、数量和 `may_have_more` 的 `ReplayCompleted` 收尾；Client 只有在尾帧覆盖的事件全部耐久后才清除该页或从最新耐久 cursor 请求下一页。未知 request 先保持未落库、未展示、未 Ack，同一 request 只发一个 `GetRequest`；`RequestStatus` 必须返回 origin device、conversation、session、Node、Agent、capability revision 与 acceptance sequence，Client 严格写入本地 route 后重新处理原 envelope。所有 frame 由一个中央 application router 顺序分发，任何恢复都绝不自动复制提交。若未来启用 PowerSync，它只能替代历史快照传输，不能改变这套身份、原子提交和精确 Ack 语义。

认证 Client 通过 `ListDirectory` 获取当前非 revoked Node/Agent 及带 route 的 conversation；目录只是可选目标与历史索引，不授予 scope。`CreateConversation` 由 Client 预生成 conversation/command/idempotency identity，必须带固定 node/agent/capability revision、可选原生 session 和安全标题；Gateway 只在 `send` scope、Agent route 当前有效且 capability 未变化时创建。数据库同时对 `(device, command)`、`(device, idempotency)` 和 conversation identity 唯一，精确并发重试返回原 descriptor，任何换目标、换标题或换 identity 都明确冲突。conversation 的持久化权威 route 是 `(nodeId, agentId, capabilityRevision, sessionId)`：接受、恢复、outbox claim 与 Node event 都从账本锁定的 route 取值，客户端自报字段与其任一不一致即拒绝，绝不改投。非空原生 session 在同一 Node/Agent/capability revision 下只能绑定一个 conversation；首次由 Node 返回的 session 只能在该 conversation 尚未绑定时原子固定。旧 migration 创建的无 route conversation 继续服务既有 request/history，但不进入新目录，直到显式迁移，避免部署期间回滚旧 Gateway 失败。

Flutter Client 的 protobuf 只停留在 Gateway infrastructure adapter：frame mapper 对 protocol、event/payload 对应关系、request status/replay/lease identity、opaque identity、uint64 sequence、UTC timestamp、审批摘要 hash 和 1 MiB envelope 上限 fail closed，再转换为不依赖 protobuf/Flutter 的完整领域 frame。中央 router 是 `GatewayLiveConnection.frames` 的唯一生产消费者，event、request status、replay completion、lease 和 heartbeat 不得由第二个 `listen`/`first`/`drain` 抢读。耐久 `EventEnvelope.device_id` 表示请求的 origin device，不是当前观察设备；已认证 stream principal 决定谁能观察，多个设备必须收敛同一字节事实。request-bound `connection.ready/lost` 属于 Agent lifecycle 并可耐久保存，Gateway transport 的连接状态则由 handshake/stream 独立表达；缺少 request identity 的业务事件一律拒绝。Client 本地事件账本必须把完整事件与 conversation cursor 在同一事务提交，并以 `expectedPreviousSequence` 做 CAS；提交成功或提交响应丢失后读回完全相同事实，才能发送包含 conversation/event/sequence 的精确 Ack。已提交的完全相同重复事件可再次 Ack 但不得再次发布到 view；同 sequence 的 connection/origin device/conversation/session/request、时间、类型、typed payload 或 envelope hash 任一变化均为冲突。缺口事件不落库、不展示、不 Ack，只按当前耐久 cursor 发出有界 replay；相同缺口尚未收敛时不重复发送 replay command。合法 Node 重连可以使后续递增 sequence 使用新的 connection ID，因此 connection ID 参与逐事件防冲突而不被错误固定为整段 conversation 常量。mapper、router、账本或收敛异常必须关闭当前流且不得自动重提用户命令。

production workspace factory 是 UI 外唯一组合点：从 OS 安全存储读 active credential 与匹配的 HTTPS trust profile，创建 gRPC channel/live connection、Drift ledger、frame mapper 和中央 router；关闭时按顺序标记在途提交 uncertain、关流、关数据库与 channel。Riverpod controller 只发布领域 directory/conversation/event/lease/安全错误，Widget 不接触 protobuf、token、nonce、签名 seed 或数据库。controller 仅对本设备持有的精确 lease/revision 安排不快于 10 秒的单次续租；新 lease、接管、过期、断流或销毁都会取消旧 timer，续租写出后若未收到更高 revision 回帧则只在原到期点撤销本地控制，不用旧 revision 重试。已确认文本在写出前只以 SHA-256 与预生成 request/command/idempotency route 原子落账；controller 在 wire write 前进入 submitting，任何已 prepare 的同步写出失败都推进为 uncertain，正文只在当前 gRPC frame 出现。审批签名从耐久 request route 取得实际 Node host，绝不信任显示名或 UI 自报 host；approve/deny、clarification、interrupt 与 lease takeover 都只能由独立用户动作触发。

Client 离线时只能保存草稿和明确列入 allowlist 的低风险元数据变更。可执行 Agent command 不进入自动排空的 Client outbox；用户点击发送但尚未建立可认证 live stream 时仍保持草稿并显示“未发送”。写出 command 后连接中断且未收到耐久 acceptance proof 时进入 `uncertain`，重连只执行 `GetRequest(requestId)` 或 replay，不重新调用 Send。

### 7.4 Direct LLM 历史、上下文与恢复

- `providerProfileId` 固定 provider kind、origin、auth realm 与 credential slot；origin/auth realm/principal 变化创建新 Profile。同身份 key rotation 递增 `credentialRevision`；模型/参数变化递增 `configurationRevision`；两类 revision 都使旧连接测试和确认失效；
- conversation 固定一个 backend target snapshot。跨 Provider/模型迁移创建新 conversation，并把用户选择的消息或摘要作为有来源的导入；默认空白，不读取旧 conversation；
- confirmed user message 与空的 `streaming` assistant message 在发出 HTTP request 前同事务写入；若本地写入失败，不发送；
- UI 可逐 delta 更新内存 assembled text，持久层 coalescer 在正常流下同一 message 最多每 250 ms 写一次；terminal、应用进入不可恢复退出路径或主动切换前立即 flush；
- 重启发现 `streaming` 而无活动 owner 的 message 时改为 `incomplete`，不得恢复成 `completed` 或自动重发；
- request builder 使用 `ConfirmedDraft` 绑定的 assistant/context revision/hash，先计算序列化硬上限和输出预留，再按系统提示 → 允许的 pinned memories → rolling summary → 最近 completed turns 组装；实际 prior-context hash 不匹配即拒绝发送并要求重新确认。context-eligible message set/content/terminal、memory、summary 或 policy 任一变化都递增 context revision；当前 `ConfirmedDraft.confirmedText` 的预发送落盘不递增，assistant reply 进入 `completed` 后才为后续轮次递增。任何单项超限都明确失败或要求用户裁剪，不无界发送全部历史；
- partial/cancelled/failed/incomplete/truncated 或 `provenance=legacy_unverified` 的 assistant message 默认不进入 builder；`legacy_unverified` 不是 terminal，用户显式引用时仍标记为不完整来源；
- connection test、2xx SSE、非 2xx body 都使用共同的 bounded reader/deadline/cancel 原语。错误体只消费有界字节用于连接复用，不进入公开错误或日志。

### 7.5 多设备冲突

会话消息只追加，不做 CRDT。每个 conversation 使用 30 秒 control lease，控制设备至多每 10 秒续租；另一设备必须通过带 revision 的 compare-and-set 显式接管。lease 过期或被接管后，旧设备的新 send/interrupt/approval 命令以 `control_lease_lost` 拒绝，已运行 Agent 请求不受影响。标题和标签等低风险元数据用 revision 乐观锁。一个 Agent 会话默认串行请求。

路由只使用 opaque `nodeId`、`agentId` 和原生 session identity。Gateway 在 acceptance 事务内固定这些值及 capability revision，并以持久化 conversation route 作为发送、恢复、dispatch 与 Node event 的唯一来源；显示名和客户端回传字段不参与路由决定。接受前目标离线可以失败，接受后不得自动改投另一 Node/Agent。只有适配器能证明同一原生执行上下文可恢复时才续传，否则进入明确失败或 `uncertain`。

### 7.6 数据分类、保留与删除

持久数据至少标记为 `content`、`security_audit`、`diagnostic_metadata`、`secret_reference` 或 `ephemeral_media`。日志管线只接受脱敏后的 diagnostic metadata；正文、原始 Agent payload 和音频不能因异常对象序列化而落入普通日志。

- 原始录音、provisional 音频和 TTS 缓存只在录制/播放设备按 `PRODUCT.md` 默认期限保存；
- 原始 STT transcript 是 local-only content，不通过 PowerSync 或 Gateway event payload 同步；
- Direct conversation、pinned memory 和 rolling summary 默认 local-only；未来同步前必须增加可见范围、删除和迁移规格；
- 同步消息删除先提交 tombstone 和 content access revocation，再异步清理活动数据库与对象存储；
- security audit 可以保留 opaque ID、动作类型和结果，但删除正文后不得保留可还原正文的 payload/hash 组合；
- 部署配置必须公开活动数据、诊断和备份各自保留期限；恢复备份后必须重新应用 tombstone、凭据吊销和设备撤销记录。

## 8. 同步方案及退出路径

M2 的实际基线为 PostgreSQL + 已认证 gRPC cursor sync + Drift/SQLite。它复用 Gateway 已有的身份、事件 replay、精确 Ack 与故障诊断，不新增第二套公开服务、授权规则、备份或运维平面；Client 离线时从 SQLite 读取完整已提交历史，可执行命令仍不进入自动排空 outbox。

PowerSync Open Edition 只保留为可选加速器，须同时满足以下条件才可进入运行依赖：

- Client SDK 的 Apache-2.0 许可和 Service 的届时许可证通过发布复核；
- 自托管认证、最小下载授权、升级、备份、监控和事故恢复有独立证据；
- Flutter/Drift 桥接通过通知、离线读取、重连、schema 升级和五平台构建契约测试；
- 相比现有 cursor sync 有可量化收益，且没有复制审批、凭据或命令权威。

PowerSync 类型和 schema 若被引入，只能存在于 `SyncAdapter`。移除它时保留 Drift schema、公共 Protobuf、领域模型和 UI，以 cursor sync 完整恢复；当前未通过上述 gate，因此不建立 `infra/powersync` 服务或配置。

## 9. Hermes 适配

### 9.1 正式链路

- 普通路径使用 HTTPS/SSE；
- 映射 health、capability、session、run、stop、approval 和错误；
- run、stop 和 approval command 都携带调用方可稳定复用的 idempotency key；adapter 重建后由 run/request identity 恢复，不自行重复提交；
- SSE 单事件默认上限 256 KiB，畸形 JSON 使当前 stream 明确失败；非 2xx 响应正文不进入普通异常或日志；
- 原生 SSE ID 优先作为恢复锚点；缺失时以 run identity、原生 sequence 和规范化 payload 生成确定性 ID。重建 adapter 后同一事实必须得到同一 ID，`Last-Event-ID` 只使用最近已接受的原生恢复锚点；
- 原生 sequence 与本地补充事件使用不重叠的单调序号空间；重复事件精确忽略，倒退、身份变化或不可证明的缺口 fail closed；
- approval 只有在 Hermes 提供稳定 approval ID、安全操作摘要、expiry 和明确 operation digest，或 Connector 可从这些固定事实确定性计算 digest 时才进入 UI；字段不完整必须变为安全契约错误，不能产生可点击批准按钮；
- Hermes 0.19 的 `approval.request` 不含原生 approval ID/expiry：Connector 以 run+确定性事件 ID 生成 approval ID；运维者必须先人工保证显式 `VOXHANDOFF_HERMES_APPROVAL_TIMEOUT_SECONDS` 与 Hermes `approvals.timeout` 相同，代码再从事件 timestamp 推导 expiry，不能把该部署前提写成自动协商证明。摘要 hash 从已脱敏 description 确定性计算。经核对的 0.19 resolution API 只接收 `choice` 且按 FIFO 队首消费，不能把不可变 approval ID 传给上游；因此 Connector 将 approval capability 公布为不可用，收到任何具体 approval decision 都保留明确 `hermes_approval_resolution_ambiguous` 阻塞并且绝不调用 resolution API。Hermes profile 必须使用 `approvals.mode: manual`，smart/off 不得注册为生产 Connector；
- Hermes 0.19 当前明确协商为 `idempotency=false`、`replay=false`、`sequenceRecovery=false`，因此生产 Connector 按 capability 门拒绝注册；不得依据请求头名称、版本号或一次成功调用推断支持；
- Connector session store 以共享加载 promise 合并冷启动并发读，并以 conversation-scoped in-flight resolution 合并自动 session 创建；同一 conversation 的并发 dispatch 只能创建和持久化一个 session。Gateway 的持久 route 唯一约束继续负责防止跨 conversation 复用；
- Gateway `ConnectNode` 是常驻双向流：即使 transport 为短 RPC 保留有限默认 deadline，
  该调用也必须显式禁用 RPC deadline；HTTP/2 ping 和应用 heartbeat 只证明活性，不能
  延长 deadline。可恢复的 Gateway 断流以有界退避重建 stream，但不得因该断流中止或
  重提已接受的 Hermes run；待新 stream 完成 handshake 和 Node registration 后才继续
  转发事件。协议 1.1 的 Node event 只有在 Gateway ledger 耐久接受后才回传精确的
  `NodeEventReceipt`；Connector 以内存中最多 256 帧的 journal 按序重放，只有匹配
  receipt 才移除事件，终态 run 也必须等 receipt 才清理，output epoch 防止断流到新
  handshake 窗口的双帧。该 journal 不跨 Node 进程重启。协议 1.0 仅为滚动升级保留
  历史 enqueue-only 语义，没有 receipt，不能承诺无损重连。认证、协议错误和显式
  进程停止不进入重连；
- 启动用户既有 gateway 前必须确认不会意外连接其消息平台；
- 远程明文 HTTP 默认拒绝，loopback 开发例外必须显式配置。

### 9.2 暂停的适配范围

Codex 研究适配器可以继续留在仓库内承担历史回归，但不得被生产 Node Connector 注册或出现在客户端目录。OpenClaw 和其他 Agent 不建立 adapter、配置入口或发行承诺。用户自接 LLM API 是直接聊天 adapter，不进入 Node/Gateway 注册、Agent 目录或 approval 协议。恢复其他 Agent 方向前必须单独完成产品决策、威胁模型、capability 映射、幂等/恢复语义与真实端到端验收。

## 10. 语音与 Direct Chat 端口

### 10.1 录音

Flutter `record` 位于 AudioCapture adapter 后。统一输出 PCM/WAV 或 STT 明确接受的流格式；采样率、声道和设备能力由运行时探测，不硬编码跨平台等价。

### 10.2 STT

STT port（本地 stdio/loopback 或用户同意的远程服务）共同实现：

- capability/health/warmup；
- start/push/end/cancel；
- provisional/final transcript；
- language、timing、confidence（若后端可用）；
- 分阶段指标和无音频错误。

免费开源默认预设是从应用拥有路径启动的 versioned faster-whisper sidecar；production Profile 只传入用户明确选择、已经存在且通过 canonical-path 校验的本地模型目录，缺失/损坏时 fail closed，禁止传模型名让引擎隐式联网下载。应用不下载模型、管理用户的 Python 环境或承诺模型质量。远程 STT adapter 只有在用户完成 provider 级显式同意后才能接收音频，并必须报告目标 origin、TLS 验证状态、是否流式上传及已知服务端保留策略；这些信息变化时暂停上传并要求重新确认。远程 STT 音频不得复用 Agent/Gateway 或 LLM API 凭据。

首轮测试集至少 30 条中文技术请求，覆盖中英混合、路径、版本号、噪声和自我修正。

`SttProviderProfile` 保存 provider kind、语言和 endpoint/consent reference；移动端远程 STT 只有在 provider 配置、凭据、TLS/保留事实和同意 UI 全部接入 production factory 后才算实现。麦克风选择属于 `AudioCaptureProfile`；无法枚举时使用显式 `system_default`，不能用空字段暗示具体设备。

### 10.3 TTS 与播放

Piper-compatible 本地服务是免费开源默认预设；当前实现选择官方 Piper HTTP 的精确版本化表面：用户在本机启动服务后，Client 仅接受 exact loopback HTTP origin，`GET /info` 不发送文本地探测 readiness，`POST /synthesize` 只接收有界 WAV。它拒绝 redirect、认证信息、路径/query/fragment 与公网 origin；不把 Piper 的 GPL-3.0 引擎或音色打包进 Client。GPT-SoVITS 或其他用户服务可实现同一 `TtsPort`。`TtsProviderProfile` 统一承载 provider 支持的 voice/speaker、speed、language 与 credential/reference；设置页只展示该 provider 真正支持的字段。远程 TTS 另保存 exact-origin consent，origin/TLS/保留事实变化时必须暂停。Client 只接收规范音频块，`media_kit` adapter 只负责播放。TTS 队列使用稳定 segment identity；最多预生成少量片段，停止后释放旧请求。完整回复、播报文本、音频缓存是三个独立数据域。

播报策略属于 AssistantProfile，而不是 TTS adapter：`off|manual|completed_only` 为最低要求；未来的 stable-sentence 模式必须由 append-only capability 和独立安全门启用。用户开始录音默认执行 `speech.stop`，不推导 Hermes interrupt。改变 TTS Profile 或播报策略时先递增 speech generation、取消旧 synth/playback 并等待有界停止，再发布新配置。

### 10.4 用户自接 LLM API

LLM API adapter 位于 Flutter infrastructure 层。它从请求绑定的 `providerProfileId + credentialRevision` 解析精确 credential slot，经 OS 安全存储取得 key，并使用确认时的 assistant/context/configuration revisions 发送。secret/reference 正文不进入确认快照。base 只允许空路径或最多四段无 query/fragment/user-info 的受限安全 path segment；adapter 只在 base 尚未以 `v1` 结尾时补该版本段，因此既支持 root 风格 provider，也支持 OpenRouter 的 `https://openrouter.ai/api/v1`，但绝不接受每请求 URL 或 redirect。

Provider Profile、conversation 和 request coordinator 位于 application/domain 层，transport 不持有 Widget state。origin/auth realm/principal 变化创建新 Profile；同身份 key rotation 递增 `credentialRevision`；model/生成参数变化递增 `configurationRevision`。两类 revision 都使连接测试结果和未发送确认失效。system prompt 只来自 `AssistantProfile`，不属于 Provider revision。空 key 只有在同一 active Profile、不执行 rotation 的明确“保留现有 credential”操作中生效；新 Profile 或 legacy reactivation 缺 key 必须拒绝。

transport 只暴露 request-scoped `test` 或 `streamCompletion`、明确 terminal 与 cancel handle。test/chat 不共享可覆盖的活动指针；所有 body 使用有界 reader，SSE 在 UTF-8/分行前按原始字节计数，并要求明确 `[DONE]` 才 completed。它禁止把提供商文本猜测成 tool、approval、执行主机或 Hermes 状态。TLS 错误 fail closed，诊断和日志不得保存 Authorization、key、完整 prompt 或 upstream error body。首版不承诺 function calling、MCP、附件、后台任务、跨端同步或 provider 代理。

## 11. 视觉架构

- SignalCore、基础 conversation shell 和可访问状态属于 AssistantProfile 的统一表现；backend badge 与 capability panel 明确标出 Direct LLM 或 Hermes，但不复制两套人格/语音/记忆界面；
- `ThemeExtension`/普通 Dart token：颜色、间距、圆角、线宽、排版、状态语义和动效时长；业务 widget 不直接散布常量；
- Widget/CustomPainter：布局、文字、交互、静态核心和可访问性；
- GLSL fragment shader：核心能量场、扫描线、噪声、色差和音频波纹；
- Rive：只在已有受审 `.riv` 资产确实减少自有 Widget 复杂度时用于按钮、连接图标等非核心微动效；没有这种资产时不为满足技术清单引入 runtime，M4 当前使用 Flutter 内建 transition；
- Platform plugins：麦克风会话、安全存储、全局快捷键、通知和窗口行为。
- 配对 presentation 只观察 Riverpod application state 并发出显式用户动作；production workflow factory 独占安全存储、TLS channel、生成 RPC client 和 coordinator 的组合与关闭，widget test 以离线 factory 替换。公开 UI state 不含 challenge、签名、nonce 或 token；
- Android 配对页的私有 CA 可通过原生 `ACTION_GET_CONTENT` 导入；文件读取限制为 128 KiB，Dart 端只接受 UTF-8 PEM certificate block，随后仍交给显式 TLS `SecurityContext` 解析。文件导入只替代脆弱的多行文本传输，不改变信任根、证书校验或 Gateway audience 校验；手工 PEM 作为备用入口保留。
- conversation presentation 只观察 production workspace 的领域快照；桌面导航与手机单列选择共享同一 selection identity。完整回复使用可选择文字，tool/terminal 保留安全阶段事实，approval 与 clarification 优先于装饰；无当前 lease 时所有可执行按钮禁用，只显示 observe 状态与显式 take-control/takeover；
- presentation 在领域层把同一 request 的耐久事件一次聚合为用户轮次、Hermes 回复、可折叠工具轨迹、未决交互和终态；`message.delta` 更新同一回复，不生成独立卡片。desktop 使用惰性列表，mobile 使用 sliver 虚拟化；顺序 live event 只增量更新当前 timeline，不能每帧重新排序完整历史；
- 信号生命核心是只读 presentation，由规范 Agent 事件、本地 voice/speech 阶段、真实 `audioLevel` 和播放 segment identity 合成为有限视觉状态；它不持有 request、approval、lease 或命令权限，不直接解释 adapter 原始事件；
- 状态优先级固定为 approval/clarification → uncertain → failed → recording/transcribing → submitting/working → speaking → completed → idle。同一时刻只发布一个主状态，次级连接、同步和播放事实由独立文字或图标呈现；
- 桌面核心在会话工作台的固定视觉安全区布局，手机核心在标题、阅读和录音三种尺寸槽位间切换；布局约束先保证正文、审批、澄清、转写确认和取消/停止操作，再分配装饰空间；
- `DesktopIntegrationPort` 是 platform plugin 的唯一 application 边界；生产 adapter 分别初始化窗口、托盘、通知和热键并发布每项 `available/degraded/unsupported` 安全状态。Linux Wayland 不调用 X11 Keybinder，而明确回落到应用内 `Ctrl+Shift+Space`；快捷键 callback 只能切换本地 voice draft。托盘成功后才启用 close-to-tray，初始化失败时不得拦截正常关闭；
- 中央 router 在耐久 replay pending 期间把已提交事件标为 `replay`，其余标为 `live`；workspace 对每次 conversation selection 另暴露明确的本地 ledger hydration 边界。desktop attention controller 只有在 hydration 完成后建立每个 conversation 的 sequence 高水位，并且只消费 router 明确标记的当前 conversation `live` approval、clarification、completed、failed 事实，因此启动/分页/切换 replay 不触发通知或历史 TTS。高水位随 directory 清理且最多保留 256 个 conversation；通知 adapter 接收 enum 而非事件 payload，因此完整回复、交互正文和摘要 hash 不可能进入系统通知；

设计系统组件以独立 catalog/use case 覆盖真实状态，再进入业务页面；catalog 工具、第三方组件库和 styling package 都只能是开发或表现层依赖，不得成为领域状态权威。优先使用 Flutter 内建语义、focus、Theme 和自有小组件；只有组件隔离测试或跨端一致性收益足以抵消依赖/迁移成本时才引入社区包。

shader 只接收 `audioLevel`、`playbackLevel`、`statePhase`、`errorPulse` 等归一化数值，不接收领域对象。录音响应只使用当前 AudioCapture session 的音量，TTS 响应只使用当前播放 segment 的包络；停止、取消、切换会话或 segment identity 失效后立即清除对应输入。所有状态必须有无动画等价表现；减少动态时禁用扫描、故障、漂移和持续波纹，只保留偏心核心、环结构差异、文字和高对比状态标记。

SignalCore 仅在 recording/transcribing/submitting/working/speaking 等活动状态持有 ticker；idle、completed、failed 和减少动态模式使用静态帧。高频麦克风/TTS 电平只重建隔离的 SignalCore/voice status 子树。PCM 包络分析通过独立 isolate 处理有界不可变字节，并以 generation/segment identity 丢弃迟到结果，禁止在 UI isolate 同步扫描长音频。

## 12. 网络与安全

### 12.1 远程访问

优先顺序：Tailscale/WireGuard 私有组网 → SSH 隧道 → HTTPS/gRPC TLS 反向代理。Gateway/Node 默认最小监听，Agent 本地接口绑定 loopback。

### 12.2 身份与权限

- 设备生成密钥对，配对后获得可撤销凭据；
- scope 至少分 `observe`、`send`、`interrupt`、`approve`、`administer`；
- 审批响应包含 approval/request/device/host identity 和签名；
- control lease 不能替代高风险审批 scope；
- 令牌只存 OS 安全存储，数据库保存引用或不可逆标识。
- Client 在同一 OS 安全存储中保留一个不透明 active credential ID 索引；完整凭据记录仍按 credential ID hash 寻址。保存顺序必须先写凭据、再写 active 引用，引用悬空或试图静默切换到另一凭据时 fail closed；

当前一个 Gateway 只有一个 owner。首次 owner bootstrap 只能在 Gateway 本机交互控制台、Embedded 私有 stdio 或部署时显式提供的一次性恢复流程完成，不能通过未认证公网请求创建。后续配对流程为：

1. Gateway 生成最长 10 分钟、单次使用并限速的 pairing challenge；
2. 新设备生成本地密钥对并提交公钥、challenge 和所请求 scope；
3. 已授权 `administer` 设备或本机控制台同时显示并核对 Gateway/设备 fingerprint、实际 Gateway 地址和 scope；
4. Gateway 校验 proof-of-possession 后签发绑定 audience、device ID、公钥和 scope 的凭据，并消费 challenge；
5. 新设备通过签名 challenge 完成读回测试，配对才显示成功。

普通 access token 最长 15 分钟；可续期设备凭据最长 30 天并在使用时轮换。Gateway 在每次建流、续期和高风险命令时检查设备/凭据撤销状态；撤销后关闭现有流并使 refresh 失效。恢复 owner 必须通过本机显式流程并撤销旧 owner 凭据，不能依赖邮件、显示名或可猜测共享秘密。所有 pairing、scope 变更、轮换、失败和撤销写入无正文安全审计。

配对 wire contract 固定为 `Begin → Inspect/Approve → Complete → Confirm`：`Begin` 只产生短期 challenge 和待核对事实，不产生可用 token；`Inspect/Approve` 仅允许已验证的 `administer` 设备或等价本机私有入口；`Complete` 校验新设备对 Gateway 给出的 domain-separated payload 的 Ed25519 签名并生成待确认凭据；`Confirm` 再校验绑定 audience、device、credential、scope 的独立签名 payload，成功后才原子激活凭据并返回 token。早期 schema 中的 `CompletePairing.device_proof`、`CompletePairingResponse.access_token/refresh_token` 只为 wire 兼容保留，服务端不得把它们作为 proof 或提前签发通道。

公钥只接受规范 Ed25519 SPKI DER，fingerprint 为规范公钥或 TLS 证书的 SHA-256；challenge、nonce、access token 和 refresh token 使用 CSPRNG。数据库只保存 bearer token 的 SHA-256 标识，不保存明文；日志、审计和错误不得包含 challenge、nonce、签名、公钥原文或 token。刷新事务必须锁定当前 credential generation，成功时同时废止旧 refresh、轮换 access/refresh 并递增 generation；已轮换 refresh 的再次出现视为重放并撤销该 credential family，而不是普通重试。可重复网络响应只能通过明确的短时加密/内存结果缓存实现，不能重新激活旧 token。Confirm 的进程内缓存按 pairing、credential 与精确签名 hash 合并并发请求，最长保留两分钟；每次返回前必须以耐久账本复核 active generation、token hash、scope 和有效期，refresh/revoke/过期后不得返回旧 token，进程重启后无缓存则保持 `uncertain`。

设备签名统一使用协议中标明的 domain、固定字段次序和长度前缀字节编码；签名 payload 由 Gateway 返回或由共享 helper 构造，禁止签署含糊 JSON、显示名或客户端自报地址。`ResolveApproval`、远程配对授权、scope 变更和撤销必须同时满足 bearer scope、实时撤销检查、单次 nonce 与设备签名；签名不能替代 control lease，也不能使 pending/expired/resolved 状态回退。

### 12.3 TLS 与秘密

- 公网 TLS 证书必须验证；
- 自签名证书要求显式导入或指纹固定；
- 禁止普通设置永久忽略证书错误；
- Flutter channel factory 只接受规范 HTTPS origin，使用系统 trust store 或调用前可解析的显式 CA，并固定有限连接 timeout；不得传入 `onBadCertificate`。唯一明文构造器必须以测试用途命名，且只接受字面量 `127.0.0.1`/`::1`；
- Flutter live transport 复用标准 protobuf 生成物和 Dart `grpc` 双向流 SDK；从 OS 安全存储读取 active credential，并只在调用 metadata 中携带 bearer。首帧必须是 Client handshake，首个 accepted handshake 有有限等待时间，但成功后的长连接不设置整体 deadline；Gateway role、协议版本、connection identity、capability、scope 和禁用附件事实必须全部本地校验。握手前业务帧、重复握手和空帧均关闭流，不自动重连；远端错误正文与底层 transport diagnostics 不进入公开异常。协议源文件的有序 SHA-256 固定于 `toolchains/protocol.json`，repository check 同时核对源码和 Dart offer，防止 schema 漂移；
- 日志在结构化写入前递归脱敏；
- 诊断导出默认不含正文，可由用户预览并选择加入脱敏样本。

### 12.4 故障语义

- 配对 unary RPC 每个用户动作只发起一次；Gateway 用 `agent-talk-error-code` trailer 携带白名单领域错误码，Client 不解析或展示远端原始 message。只有明确的领域/状态拒绝可进入 failed/待批准，传输超时、断线、取消、未知状态或调用后本地异常均进入 `uncertain`，必须由用户显式恢复并复用已经持久化的同一请求/签名；
- gRPC 故障：停止 live delta，以耐久快照恢复；
- cursor-sync 故障：本地已提交历史可读，未耐久 live 事件不展示、不 Ack；可选 PowerSync 故障同样退回 cursor sync；
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

以下资料是 2026-07-25 基线的复核入口；依赖升级时重新检查，不把链接当作永久兼容保证：

- [Flutter 支持平台](https://docs.flutter.dev/reference/supported-platforms)
- [Flutter fragment shaders](https://docs.flutter.dev/ui/design/graphics/fragment-shaders)
- [Flutter accessibilityFeatures](https://api.flutter.dev/flutter/dart-ui/PlatformDispatcher/accessibilityFeatures.html)
- [XDG GlobalShortcuts portal](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.GlobalShortcuts.html)
- [hotkey_manager](https://pub.dev/packages/hotkey_manager)
- [tray_manager](https://pub.dev/packages/tray_manager)
- [window_manager](https://pub.dev/packages/window_manager)
- [local_notifier](https://pub.dev/packages/local_notifier)
- [record 平台能力矩阵](https://pub.dev/packages/record)
- [media_kit](https://github.com/media-kit/media-kit)
- [faster-whisper](https://github.com/SYSTRAN/faster-whisper)
- [GPT-SoVITS](https://github.com/RVC-Boss/GPT-SoVITS)
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)
- [Riverpod](https://pub.dev/packages/riverpod)
- [gRPC Dart basics](https://grpc.io/docs/languages/dart/basics/)
- [Buf 文档](https://buf.build/docs/)
- [Drift 平台支持](https://drift.simonbinder.eu/platforms/)
- [Drift Native 数据库与 SQLite build hooks](https://drift.simonbinder.eu/platforms/vm/)
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
| Client → Direct LLM | 旧 key 发给新 origin、跨 Provider 历史泄漏、无界响应、终态伪完成 | Profile/credential identity、conversation 隔离、目标确认、上下文/响应上限、明确 `[DONE]` terminal |
| 开发/CI → 发布制品 | 依赖/Action/生成物投毒、签名泄露 | lockfile、最小依赖、固定 CI 权限、SBOM、签名和可重复质量门 |

### 15.3 重点攻击故事与控制

- **重复执行/错主机执行**：重放、重连或 failover 让命令执行两次或改投同名主机。以数据库 uniqueness、acceptance + dispatch outbox 同事务、opaque target、status lookup 代替 resend；任何重复执行为发布阻断。
- **审批混淆**：迟到/并发响应、摘要替换或 approval ID 复用。响应必须绑定 request/Agent/Node/native ID、摘要 hash、device、scope、lease、expiry 和 idempotency，只允许 pending 的 CAS 进入一个终态。
- **事件串线/伪完成**：恶意 sequence、旧 connection、未知事件或可修订 delta 改变当前会话。Core 按 connection/session/request/sequence/terminal state 拒绝；未知事件不得映射为成功；uncertain 不播报完成。
- **secret/正文泄露**：Authorization、URL、stderr、上游错误体、native payload 或诊断导出携带凭据/正文。所有日志在序列化前递归脱敏，普通诊断只存 metadata，raw payload 只进入受限、限时且显式选择的诊断域。
- **Profile/历史混淆**：修改 Provider origin/model 后沿用旧 identity、credential 或 conversation，把旧 key/历史发给新服务。origin/认证变化创建新 Profile，模型变化递增 revision，conversation 固定 target，迁移需预览确认；任何目标变化撤销旧确认。
- **本地 executable 替换**：PATH 中伪造 `codex`、`hermes`、Python 或播放器。PoC 可接受开发者显式命令；发行版只能启动 bundled 或显式信任且校验 canonical path、owner 和版本的 executable。
- **资源耗尽**：无限 SSE、巨大帧/错误体、深对象、delta 洪泛或音频队列拖垮进程。每个边界定义 frame/body/depth/rate/queue 上限、deadline、backpressure、cancel 和 supervisor；单域崩溃退化而不丢文字事实。
- **UI/语音欺骗**：Agent 内容伪装成审批框、完成状态或危险链接。trusted chrome 与 untrusted content 分层，清理主动内容和控制字符；安全状态只来自规范事件，TTS 不朗读 uncertain/approval-pending 为成功。
- **供应链/迁移攻击**：恶意 dependency、CI action、schema 或 migration 继承高权限。使用 lockfile、协议生成检查、最小 CI 权限、SBOM/许可证/secret scan、签名制品和 expand-first migration；生产禁止 destructive reset。

### 15.4 严重度校准

| 严重度 | VoxHandoff 语境 |
| --- | --- |
| Critical | 未认证/已撤销设备获得 administer/approve；自动批准高风险操作；重放导致重复或错主机执行；公网可达 RCE/管理员凭据泄露 |
| High | observe-only/旧设备可 send/interrupt/approve；跨会话串线影响用户操作；远程 STT 未同意上传；普通日志持久化可用 secret/大量私密正文；协议降级把失败/uncertain 变成功 |
| Medium | 已认证低权限设备或恶意 Agent 造成有界 DoS/崩溃但无执行越权；保留/删除延迟违反已展示策略；单个 sidecar 失败但耐久事实完整 |
| Low | 无实际攻击路径的版本/粗粒度 timing 暴露；仅开发 PoC 的本地不便；不影响可信文字和审批的视觉/TTS 偏差 |

威胁模型在新增网络入口、附件、多用户、公共云、后台音频、Agent 类型、Provider 类型、记忆同步、权限 scope、存储权威、更新机制或 trust boundary 时必须先更新。安全扫描发现的新攻击故事应先回写本节和相应验收门，再进入实现修复。
