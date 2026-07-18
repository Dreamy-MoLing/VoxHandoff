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

## 4. 代码和进程边界

### 4.1 Flutter Client

负责：

- 页面、可访问性、动画和用户输入；
- 麦克风、音频播放、本地 STT/TTS 调度；
- gRPC live stream 与 HTTPS 配对；
- PowerSync/Drift 本地读取和 outbox UX；
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
- 配对、登录、健康、配置、大附件：HTTPS；
- Desktop host ↔ bundled sidecar：JSON-RPC 2.0 over stdio/JSONL；
- Node ↔ Codex：app-server stdio；
- Node ↔ Hermes：HTTPS/SSE，或同机 TUI Gateway 协议；
- Adapter ↔ OpenClaw：Gateway WSS；
- Client durable sync：PowerSync → local SQLite。

WebRTC 不进入默认主链路，因为不持续上传原始音频。未来远程流式音频必须作为独立 media channel，不混入 Agent event stream。

### 5.2 Envelope

公共 schema 至少表达：

```proto
message Envelope {
  uint32 protocol_version = 1;
  string event_id = 2;
  string connection_id = 3;
  string device_id = 4;
  string conversation_id = 5;
  string request_id = 6;
  uint64 sequence = 7;
  google.protobuf.Timestamp occurred_at = 8;
  oneof body {
    ClientCommand command = 20;
    AgentEvent event = 21;
    Ack ack = 22;
    Heartbeat heartbeat = 23;
  }
}
```

规则：

- `sequence` 在 conversation 内由 Gateway 严格递增；
- Client command 另带 `commandId` 和 `idempotencyKey`；
- Gateway 先事务持久化，后广播 `request.accepted`；
- Client 以 event ID 去重、以 sequence 检测缺口；
- 未知字段可忽略，缺少必需 capability 必须拒绝并报告；
- Protobuf 字段号永久保留，删除字段进入 `reserved`；
- Adapter 原始 payload 只保留在受限诊断中，不作为 UI 协议。

### 5.3 Capability

握手至少协商：

- stream/history/session create-resume；
- interrupt/clarification/approval/tool events；
- attachment 与大小限制；
- idempotency/replay/sequence recovery；
- append-only delta 或可修订 delta；
- Agent、adapter、protocol 版本；
- 实际执行主机和可用 scope。

UI 由 capability 决定功能是否出现，不通过失败探测能力。

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
- `command_outbox`、`gateway_outbox`；
- `attachments`：hash、metadata、encrypted object reference；
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

### 7.4 多设备冲突

会话消息只追加，不做 CRDT。每个 conversation 使用短期 control lease；另一设备必须显式接管。标题和标签等低风险元数据用 revision 乐观锁。一个 Agent 会话默认串行请求。

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
- WebSocket 实验传输不直接对公网开放；
- 不依赖 Codex Desktop 当前窗口或焦点会话。

### 9.2 Hermes

- 普通路径使用 HTTPS/SSE；
- 映射 health、capability、session、run、stop、approval 和错误；
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

首轮测试集至少 30 条中文技术请求，覆盖中英混合、路径、版本号、噪声和自我修正。

### 10.3 TTS 与播放

GPT-SoVITS adapter 生成规范音频块，`media_kit` adapter 播放。TTS 队列使用稳定 segment identity；最多预生成少量片段，停止后释放旧请求。完整回复、播报文本、音频缓存是三个独立数据域。

## 11. 视觉架构

- Widget/CustomPainter：布局、文字、交互、静态核心和可访问性；
- GLSL fragment shader：核心能量场、扫描线、噪声、色差和音频波纹；
- Rive：按钮、连接图标等非核心矢量微动效；
- Platform plugins：麦克风会话、安全存储、全局快捷键、通知和窗口行为。

shader 只接收 `audioLevel`、`statePhase`、`errorPulse` 等归一化数值，不接收领域对象。所有状态必须有无动画等价表现。

## 12. 网络与安全

### 12.1 远程访问

优先顺序：Tailscale/WireGuard 私有组网 → SSH 隧道 → HTTPS/gRPC TLS 反向代理。Gateway/Node 默认最小监听，Agent 本地接口绑定 loopback。

### 12.2 身份与权限

- 设备生成密钥对，配对后获得可撤销凭据；
- scope 至少分 `observe`、`send`、`interrupt`、`approve`、`administer`；
- 审批响应包含 approval/request/device/host identity 和签名；
- control lease 不能替代高风险审批 scope；
- 令牌只存 OS 安全存储，数据库保存引用或不可逆标识。

### 12.3 TLS 与秘密

- 公网 TLS 证书必须验证；
- 自签名证书要求显式导入或指纹固定；
- 禁止普通设置永久忽略证书错误；
- 日志在结构化写入前递归脱敏；
- 诊断导出默认不含正文，可由用户预览并选择加入脱敏样本。

### 12.4 故障语义

- gRPC 故障：停止 live delta，以耐久快照恢复；
- PowerSync 故障：本地历史可读，live 事件标记等待持久化；
- Gateway/PostgreSQL 故障：草稿保留，未确认命令不发送；
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
