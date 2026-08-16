# VoxHandoff 产品规格

## 1. 产品定义

> 当前执行优先级（2026-08-13）：只开发 Android 手机端 MVP。产品支持范围为
> Android（当前优先）、iOS（后续）、macOS 和 Windows；Linux 仅作为
> Hermes/Agent/服务端部署主机，不提供客户端。共享 Flutter 语义和协议模型，
> macOS/Windows 后续按同一里程碑适配，iOS 在后续移动端阶段适配；后台监听、
> 唤醒词、全双工语音和本地手机 Agent/STT sidecar 均延后到 Android MVP 的实体
> 设备验收之后。

VoxHandoff 是面向 Hermes 用户的本地优先、GUI 优先个人语音助手。它服务于长期个人助理、自然聊天和情感陪伴：用户始终面对同一个可命名、可塑造人格、可选择声音并可管理记忆的助手，而不是在两个互不相干的产品之间切换。

同一个助手可以组合两类后端能力：用户自接的 OpenAI-compatible LLM API 负责纯聊天或陪伴；Hermes 负责工具调用、任务执行、审批、控制租约、执行主机和可追溯的真实 Agent 状态。人格、声音、记忆策略、SignalCore 和基础聊天界面属于助手；工具轨迹、审批、lease 和执行事实只在 Hermes capability 真实存在时展示。

核心体验是自然、连续、可打断的分轮语音交互：看得见当前目标，能编辑和确认文字，能停止播报，任何语音故障都不丢文字。用户开口默认只打断 TTS；是否中断 Hermes 工作必须是独立明确动作。当前不承诺后台常听或持续原始音频全双工。

VoxHandoff 不是新的 Agent 框架、公共模型中转服务、桌面 UI 自动化工具，也不把 Direct LLM 文本伪装成工具执行、审批或系统权限。Hermes 是当前主要支持且唯一具有 Agent 语义的后端；Codex 代码只保留历史回归价值，OpenClaw 暂停。

### 1.1 目标用户与成功标准

目标用户是希望长期使用一个私人语音助手、同时需要 Hermes 完成真实工作的个人用户。产品成功至少意味着：

- 助手身份、人格、声音、记忆和视觉在聊天与工作之间保持连续；
- 每轮发送前都能看见并确认文字与实际目标，切换目标不会沿用旧确认；
- 日常聊天无需启动 Hermes；需要工作时能明确进入 Hermes capability，并看到真实主机、工具、审批和状态；
- 长期聊天不会无限发送全部历史，用户可以查看、编辑和删除记忆；
- 任一外部服务、语音环节或视觉效果失败时，已确认文本、已收到回复和安全状态仍然可用。

## 2. 支持范围

### 2.1 平台

同一 Flutter 客户端代码库支持以下平台：

- Android（当前优先）；
- iOS（后续）；
- macOS；
- Windows。

平台共享产品语义、协议、数据模型、视觉 token 和状态机。系统能力允许差异化实现：

- macOS/Windows 桌面端可以启动随应用分发的本地 sidecar、使用全局快捷键和托盘；
- 移动端的 Agent/聊天后端只连接远程 Hermes Gateway 或用户配置的 LLM API，不启动 Node、Hermes 或本地语音 sidecar；语音可以使用用户明确同意的远程 STT/TTS；
- iOS/Android 第一版只承诺前台按键说话，不承诺后台常听或自定义唤醒词；
- Linux 不提供客户端支持，仅作为 Hermes/Agent/服务端部署主机。

桌面全局快捷键只切换本地语音草稿录制，不确认草稿、不发送请求、不处理中断、审批或澄清。通知只使用固定的阶段文案，不携带完整回复、转写、审批摘要或澄清正文；只有托盘初始化成功后才允许“关闭到托盘”，否则保留平台正常退出行为。应用内 `Ctrl+Shift+Space` 是全局热键不可用时的可见回退。

首个持续集成和开发目标是 Android 实机；macOS/Windows 作为后续桌面目标、iOS
作为后续移动目标，均按 `DELIVERY.md` 的里程碑逐步适配，不能因首发顺序删减
公共协议能力。

### 2.2 Hermes 与自接 LLM API

Hermes 是唯一首发和当前产品支持的 Agent。正式链路为 Flutter Client → VoxHandoff Gateway/PostgreSQL → Node Connector → Hermes HTTPS/SSE；Node 与 Hermes 同机部署时仍只连接显式配置的 loopback endpoint，不复用或管理用户已有的消息平台 gateway。

“产品支持”不等于绕过安全门。生产 Connector 只注册明确提供事件流和幂等 run submission 的 Hermes endpoint；Hermes 0.19.0 没有广告所需幂等 capability，adapter 因缺失而保守协商为 `idempotency=false`，所以该版本可用于隔离 PoC，但不能作为已完成的生产纵向链路。UI 必须显示配置/能力阶段错误，不能退回自动重提或把直接 adapter 成功冒充 Gateway/PostgreSQL 端到端成功。

用户还可以建立一个或多个 Direct LLM Provider Profile，作为不带工具执行能力的聊天来源。首版只承诺小型、版本化的 OpenAI-compatible chat-completions 端口：API origin、模型、认证方式和连接测试均属于 Profile。API key 只保存在当前设备的 OS 安全存储并与不可变 Profile ID 绑定；正文与 key 不经过 VoxHandoff Gateway/公共中转。默认不上传录音，只有绑定了目标快照的已确认文本才会发送给该 API。该来源没有 Agent host、tool event、approval、control lease 或跨设备 command 语义；取消、失败、提前 EOF、超时和超限必须以各自终态保存已经收到的正文，绝不能映射成 Hermes 的幂等安全承诺。

仓库中既有 Codex 研究适配器和历史测试只作为已验证过的协议隔离样本保留，不进入产品目录、生产 Connector、UI、发行兼容表或后续功能承诺。OpenClaw 和其他 Agent 不建立 adapter、配置入口或发行承诺。除 Hermes 外的 Agent 类型仍属于产品方向变更，必须先更新本规格、威胁模型、capability 契约和独立真链路门；用户自接的纯 LLM API 不因此成为通用 Agent 插件。

### 2.3 部署形态

- Embedded：客户端、本地 Gateway/Node 和本地 Agent 在同一桌面设备；
- Self-hosted：Gateway 部署在用户的电脑、家庭服务器或 VPS，Node 主动出站连接；
- Multi-device self-hosted：同一 Hermes 会话可由多个已授权设备观察，由一个持有 control lease 的设备操作。

项目不运营公共中转云。所有远程部署由用户控制。

当前基线采用单所有者模型：一个 Gateway 只有一个管理所有者，可以授权其多台设备。设备显示名、Agent 名和主机名只用于展示，权限判断只能使用不透明 ID、凭据、scope 和签名。多人账号、组织租户和共享审批不属于当前 MVP；逻辑数据模型可以为未来扩展保留 `userId`，但不得因此放宽当前授权边界。

## 3. 统一个人助手体验

### 3.1 Assistant Profile

产品至少有一个当前启用的 `AssistantProfile`。这是逻辑产品模型，具体 Dart 类型可以按现有分层拆分，但以下语义必须由一个稳定的 `assistantId` 关联：

| 配置域 | 最小内容 |
| --- | --- |
| 身份与人格 | 名称、人格描述、系统提示、首选语言 |
| 记忆 | 记忆策略、固定记忆、滚动摘要设置、删除与导出策略 |
| 语音输入 | STT Profile、语言、麦克风选择、远程上传同意引用 |
| 语音输出 | TTS Profile、音色、语速、语言、自动播报策略 |
| 交互 | 用户开口时的 TTS 打断、Hermes 中断是否另行确认、通知策略 |
| 视觉 | SignalCore 主题、动态强度、音频响应和减少动态覆盖 |
| 后端 | 默认聊天 Backend Profile、Hermes Work Profile |

`AssistantProfile` 只保存普通配置和 opaque 引用，不保存 API key、Gateway token、设备私钥或 Hermes credential。它有单调 `assistantRevision`；人格、system prompt 或影响请求/交互的策略变化都会递增 revision 并撤销旧确认。首个可用版本只要求一个活动助手，不要求多助手管理界面；数据和会话仍必须显式带 `assistantId`，避免以后通过全局单例继续耦合。

### 3.2 能力而不是两个产品

- 基础会话、草稿、人格、记忆、声音、SignalCore 和消息终态使用同一套界面语义；
- 每一轮仍显示实际 backend 与隐私目标，统一体验不能隐藏数据发往哪里；
- Direct LLM 只提供聊天 capability；Hermes 提供聊天与工作 capability，具体按钮由真实协商能力决定；
- 从 Direct LLM 切到 Hermes 工作不是隐式路由。应用必须展示将发送的确认文本、可选上下文和 Hermes 目标，并要求新的确认；
- Hermes 工作结束后，完整结果可以成为该助手会话的一部分，但工具事实、审批、lease 和执行主机不能被压成普通 LLM 文本或由 LLM 伪造。

### 3.3 Provider Profile、凭据与会话隔离

- `providerProfileId` 是 opaque、不可变的服务商/凭据安全边界。创建 Profile 时固定 provider 类型、规范 API origin、auth realm 和稳定 credential slot；修改 origin、auth realm 或认证 principal 必须创建新 Profile ID，不得原地复用旧 ID。模型、非秘密生成参数或 provider 能力变化产生单调 `configurationRevision`；既有 conversation 继续绑定旧快照，使用新模型时创建新 conversation 或执行显式迁移；
- 同一 Profile 内只有用户明确声明为同一身份的 key rotation 才能替换 credential，并递增 opaque `credentialRevision`，使旧连接测试证明和未发送确认立即失效；secret/reference 正文不进入确认快照。空 key 只在 Profile 身份和 credential revision 都未变化时表示“保留现有 key”。创建新 Profile 或改变 identity 时空 key 必须拒绝，绝不能把旧服务商 key 发给新 origin；
- `conversationId` 是历史和上下文边界，不能用 Profile ID 代替。每个 conversation 固定 `assistantId`、backend kind 和 backend target；一个 Profile 可以有多个相互独立的 conversation；
- 改变 Provider、模型或 Hermes route 默认创建新 conversation。跨 Provider 迁移只能由用户显式发起，先预览将复制的内容，再选择“空白新会话、复制选中消息或仅复制滚动摘要”；默认不发送旧服务商历史；
- 删除 Profile 时先阻止新请求，再让用户选择保留本地历史、导出或删除。凭据删除和历史删除是两个独立动作。

### 3.4 长期记忆与上下文

每个 conversation 拥有独立历史和单调 `contextSnapshotRevision`；助手记忆与 conversation 历史不是同一数据。任何会改变下一请求 assembled payload 的事实都递增该 revision 并撤销旧确认，包括 context-eligible message 的新增、终态或正文变化，以及记忆、摘要或 context policy 编辑。当前这次已确认的 user text 单独保存在 `ConfirmedDraft`，其预发送持久化不算“既有上下文变化”；该轮 assistant reply 进入 `completed` 后才为后续请求递增 context revision。最小可用上下文按以下顺序组合，并受请求硬预算约束：

1. 助手系统提示；
2. 用户显式固定且允许发送给当前 backend 的记忆；
3. 当前 conversation 的滚动摘要；
4. 在剩余预算内从新到旧选择的最近完整轮次。

部分、取消、失败、`incomplete`、`truncated` 或带 `provenance=legacy_unverified` 的 assistant 回复默认不进入后续可信上下文。`legacy_unverified` 是来源/可信度标记，不是第七种运行终态。用户必须能查看每条固定记忆的来源、适用范围和更新时间，并能编辑或删除；滚动摘要必须可查看、重建和清空。记忆默认保存在当前设备，未来同步到 Gateway 前必须单独定义加密、授权、删除和 backend 可见范围。

## 4. 核心用户流程

### 4.1 首次配置

用户可以：

1. 创建或恢复当前 Assistant Profile，设置名称、人格、系统提示、语言、记忆和 SignalCore 偏好；
2. 配置 Hermes Work Profile（添加本机或远程 Gateway、配对并选择已确认的 Connector），以及零个或多个 Direct LLM Provider Profile；
3. 配置 STT/TTS Profile，并分别测试录音、识别、聊天后端与播放；
4. 选择默认聊天后端、Hermes 工作后端、会话、麦克风、声音、语速、播报和打断策略。

错误必须指出失败环节，不使用无法行动的统一“请求失败”。

### 4.2 发起请求

默认流程：

1. 用户按住快捷键或点击录音；
2. 客户端明确显示麦克风占用和音量；
3. 流式 STT 显示临时字幕；
4. 结束录音后生成 final transcript；
5. 用户修改、取消或确认；确认动作同时生成不可变的文本 revision 与发送目标快照；
6. 客户端显示当前助手、backend、conversation/Profile，以及 Hermes 的 Agent、Node、capability revision、原生 session 和实际执行主机（如适用）；
7. Hermes 经 Gateway 持久化后返回 `request.accepted`；自接 LLM API 则仅在用户设备发出一次文本请求；
8. Client 根据真实事件或 API 流式文本持续更新回复；
9. 回复按明确终态持久化；只有 `completed` 回复可进入完成式 TTS，稳定语义句提前播报仍须满足 append-only 和 identity 门；
10. Hermes 任务结束后跨设备收敛为同一最终记录；自接 LLM 的历史默认只保存在配置该 key 的本机。

可提供“低风险请求直接发送”，但必须由用户显式开启；审批、发布、删除、付款、授权、凭据、sudo 等动作永远不能自动批准。

“直接发送”只允许跳过 final transcript 的人工编辑确认，不能替代 Agent 后续产生的审批或澄清。该设置按设备和精确目标独立保存，默认关闭；切换 ChatSource、Assistant、LLM Profile、conversation、Agent、Node、capability revision、原生 session 或实际执行主机后恢复为需要确认。

确认快照至少绑定：不可变的 normalized `confirmedText`、draft ID/revision、text hash、`assistantId`、单调 `assistantRevision`、conversation 的 `contextSnapshotRevision` 与 `contextSnapshotHash`、ChatSource、`conversationId` 和 backend target revision。Direct LLM 还绑定 `providerProfileId`、`credentialRevision`、`configurationRevision`、规范 origin 与 model；Hermes 还绑定 `agentId`、`nodeId`、capability revision 和原生 session 标识。当前协议中 `nodeId` 就是安全意义上的实际执行主机 identity，单独的主机显示名只用于展示。任一权威值在确认后变化都使确认失效并回到可编辑草稿；发送函数必须从该对象读取正文和目标，不能在点击发送时重新读取一组可能已经变化的全局当前值。

发送前目标离线时保留为草稿；恢复连接后必须再次确认，不能自动排队执行。Hermes 命令进入传输后若无法证明 Gateway 是否接受，则进入 `uncertain` 并只查询原 request，不静默改投其他主机或 Agent。Direct LLM 没有远端幂等查询能力，断线后保留部分回复和失败/不完整终态，由用户决定是否以新 request 重试。

### 4.3 实时反馈

反馈分三层：

- 即时确认：本地动画、提示音或“收到”等确定性短句，不声称任务已开始或完成；
- 工作反馈：只根据真实 Agent/tool/connection 事件说明当前阶段，不生成虚构百分比；
- 回答播报：从完整文字中安全切分稳定句，过滤代码、日志、长路径、表格和秘密后播放。

用户开始说话时默认只停止 TTS，不取消 Agent。中断 Agent 必须是独立明确动作。

### 4.4 审批与澄清

审批面板必须显示：

- Agent 与会话；
- 操作实际执行主机；
- 工具名称和完整操作摘要；
- 风险与权限范围；
- 批准、拒绝和补充信息入口。

语音可以朗读“需要确认”，但不能直接替用户批准高风险操作。断线时审批保持未批准或遵循 Agent 原始超时策略。

审批具有 `pending`、`approved`、`rejected`、`expired`、`cancelled` 五类状态，并且最多只能进入一个不可变终态。只有持有当前 control lease 和 `approve` scope 的设备可以响应；重复响应按同一 idempotency key 返回原结果，并发或迟到响应必须明确拒绝。Gateway/Client 重启后仍须恢复未决审批，任何断线、超时、语音输入或设备接管都不能推导为批准。

### 4.5 多设备

- 所有已授权在线设备可观察同一会话；
- 一个 conversation 同时只有一个控制设备；
- 其他设备发送、审批或中断前必须显式接管；
- 默认仅前台控制设备播放 TTS；
- 历史、完整回复、失败和审批结果同步；
- 原始录音、临时 STT 音频和 TTS 缓存默认不同步。

control lease 过期只撤销发送、审批和中断能力，不改变 Agent 已在执行的请求。新设备接管后必须先看到当前请求、未决审批和实际执行主机；旧设备的迟到命令以稳定错误拒绝，不得在后台补发。

## 5. 功能需求

### 5.1 录音与 STT

- 支持按住说话和点击开始/结束；
- 录音、权限拒绝、静音、设备断开和格式错误分别报告；
- 流式 provisional transcript 与 final transcript 必须区分；
- final transcript 可编辑并保留原识别版本用于本地诊断；
- 原始录音在 final transcript 产生或用户取消后立即删除，不进入同步数据库；可恢复的 STT 失败只允许在应用私有临时目录保留至用户放弃、应用下次启动或 24 小时，以最早者为准；
- STT/TTS 都是独立配置的端口；项目只维护稳定的 capability、测试、失败隔离和隐私提示，不内置模型、音色或云端账号生命周期；
- 免费开源默认预设是应用拥有路径的本地 faster-whisper STT sidecar 与用户自装的 Piper-compatible TTS 服务：设置页只探测 readiness、不会下载模型或接受命令；Piper 必须完成连接测试。任一端不能运行时仍保持文字聊天可用；
- production local STT 必须使用用户明确选择、已经存在且通过规范路径校验的本地模型；缺失或损坏时 fail closed，不能把模型名交给引擎触发隐式联网下载；
- 远程 STT 默认关闭；启用时必须显示音频将离开设备、目标服务、TLS 状态和已知保留策略，并取得用户对该 provider 的显式同意；
- 用户可以选择实际麦克风和识别语言；平台无法枚举设备时明确标为“系统默认”，不能伪装已选择具体设备；
- 没有 STT 时仍可输入文字使用所有 Agent 功能。

### 5.2 Hermes 会话

- 创建、选择和恢复明确会话；
- capability 决定是否显示历史、流式 delta、中断、审批、澄清、工具事件、附件和续传；
- 每次请求有稳定 `requestId`、`commandId` 和 `idempotencyKey`；
- 同一 Agent 会话默认串行 turn；
- 断线且提交状态不明时进入 `uncertain`，禁止自动重发；
- 失败、取消、中断确认和未知状态必须分别表示。

Gateway 可以在接受请求前因目标不可用而拒绝，但一旦返回 `request.accepted`，该请求就固定到原 `nodeId`、`agentId` 和原生会话。目标故障只能恢复同一执行上下文、进入失败或进入 `uncertain`，不得静默故障转移并重新执行。

### 5.3 Direct LLM conversation、上下文与消息终态

- 一个 Provider Profile 可拥有多个 conversation；历史按 `conversationId` 隔离，不能按全局默认 Profile 共享；
- 每轮请求只发送当前 conversation 经预算器选中的系统提示、允许的固定记忆、滚动摘要和最近完整轮次，禁止无界发送全部历史；
- 流式 delta 可以实时显示，但数据库写入必须合并；正常流下每条 assistant message 最多每 250 ms 刷盘一次，terminal 到达时立即写入最终文本和终态；
- 请求上下文与响应都必须有硬字节上限、deadline 和取消；连接测试、正常 SSE 和非 2xx 错误体全部采用有界读取或立即安全取消；
- 连接测试使用独立 transport/request owner，不得取消、覆盖或复用活动聊天 request；
- 切换 ChatSource、Provider Profile、conversation 或修改活动配置前，必须先显式取消当前 Direct LLM request 并写入 `cancelled`，或者阻止切换；隐藏页面不得让旧 request 写入新会话、触发当前会话 TTS 或覆盖新状态；
- 页面销毁、transport close、TTS generation 和 HTTP cancel 使用独立 generation/identity。停止 TTS 不取消聊天；取消聊天必须取消其 TTS generation，但不删除已收到文字。

Direct LLM assistant message 使用以下互斥终态：

| 状态 | 语义 |
| --- | --- |
| `streaming` | 正在接收，文本可变化，不进入后续可信上下文 |
| `completed` | 收到 adapter 规定的明确完成标记（当前 SSE 为 `[DONE]`），完整终态已持久化 |
| `cancelled` | 用户或生命周期显式取消，保留部分文本，不自动重试 |
| `failed` | 在产生有效 assistant 正文前发生 timeout、网络、TLS、HTTP/protocol 等失败，保存安全错误 |
| `incomplete` | 已有部分正文后提前 EOF、缺少完成标记、超时、断网或无法证明完整，保留部分文本 |
| `truncated` | 响应达到大小/内容上限而被主动终止，保留上限内文本 |

只有 `completed` 可以触发完成式 TTS、滚动摘要和默认后续上下文。`cancelled`、`failed`、`incomplete`、`truncated` 不能通过一个布尔 `completed=true` 合并。

### 5.4 完整回复与语音回复

必须保存两类独立内容：

1. 完整回复：Agent 原始可展示文字和结构化事件；
2. 播报文本：一至三句话或若干稳定短句，不影响完整回复。

播报文本按以下顺序产生：

1. Agent 明确提供的结构化摘要；
2. 追加稳定的自然语言句；
3. 确定性规则提取最终状态和自然语言；
4. 可选摘要模型；
5. 无法安全摘要时只播报完成/失败状态并提示查看文字。

摘要或 TTS 失败不得修改、覆盖或延迟完整回复。

### 5.5 TTS

- TTS 通过 provider-neutral port 接入；Piper-compatible 本地服务是免费开源默认预设，GPT-SoVITS 等服务是可选用户配置；
- 支持预热、流式或分段生成、播放队列和取消；
- 第 N 段播放时可并行生成 N+1 段；
- 每段绑定 request、message revision 和 segment index；
- 过期段、已中断请求或切换会话后的段不得继续播放；
- 用户开始录音或点击停止后 300 ms 内停止/淡出；
- TTS 离线时降级为字幕，不阻塞 Agent。
- 用户可配置 provider、音色/说话人、语速、语言和自动播报策略；不支持的字段必须在对应 provider UI 中明确隐藏或标为不可用；
- 远程 TTS 首次向 exact origin 发送回复文字前必须说明正文将离开设备并取得同意；origin、TLS 或已知保留策略变化后暂停并重新确认；
- 改变 TTS Profile 时必须取消并等待旧 generation/播放停止，旧音频不得在新配置或新 conversation 下继续播放。

### 5.6 设置与诊断

- Hermes Gateway、用户 LLM API、STT/TTS 独立连接测试；
- 助手名称/人格/系统提示、记忆、默认 backend、麦克风、识别语言、快捷键、音色、语速、TTS 语言、自动播报、打断策略和动态效果设置；
- OS 安全存储保存密钥，普通数据库只保存引用；
- 诊断导出前预览，认证头、令牌、密钥和敏感 payload 脱敏；
- 显示组件版本、capability、当前连接、同步游标和最近失败阶段；
- 不提供永久忽略所有 TLS 错误的普通选项。

### 5.7 数据生命周期

默认保留规则如下，用户可以选择更短期限，但延长敏感数据保留必须明确说明影响：

| 数据 | 默认位置 | 默认保留 |
| --- | --- | --- |
| 原始录音/临时音频 | 录制设备的应用私有临时区 | final/cancel 后立即删除；失败残留最长 24 小时 |
| 原始 STT transcript | 录制设备本地数据库 | 7 天，可立即删除或关闭保留 |
| Hermes 用户确认文本与完整回复 | Gateway 权威历史库和授权设备副本 | 保留至用户显式删除或部署者配置的已展示期限 |
| Direct LLM conversation 与消息终态 | 配置该 Provider 的设备本地数据库 | 保留至用户按 conversation/Profile 删除；默认不同步 |
| 固定记忆与滚动摘要 | 当前设备本地数据库 | 保留至用户编辑/删除或删除 Assistant；默认不同步 |
| TTS 音频缓存 | 播放设备本地缓存 | 应用退出或 24 小时，以最早者为准 |
| 无正文诊断与阶段指标 | 本地/Gateway 诊断库 | 7 天；运维者延长时必须公开配置 |

删除同步历史时先写入授权范围内可见的 tombstone，停止向设备分发正文，再从活动存储和对象存储清除内容；备份中的最长残留时间必须由部署者配置并在删除确认前显示。导出、删除和诊断预览不得要求 Client 获得 Gateway 管理员密钥。

附件字段目前只是协议扩展点。当前 MVP 不承诺上传或转发任意文件；在某个后续里程碑明确加入附件的产品类型、大小、扫描、授权、加密、保留和 Agent 映射规则之前，所有正式 adapter 必须协商 `attachments=false`，UI 不显示附件入口。

## 6. 视觉与交互规格

视觉主命题是原创的 SignalCore：借鉴 Jarvis/Fairy 一类数字伙伴的即时响应、空间层次和角色存在感，但不复制任何第三方角色、轮廓、贴图、字体、Logo、截图、音频、台词或配音。允许使用受控的柔和能量场、辉光、轨道、结构形变和音频响应；这些效果必须与真实状态相关，不能遮蔽正文或伪造执行进度。

SignalCore 是界面的首要视觉主体，也是只读的状态表现。它以核心几何、分层轨道、方向结构、明暗和状态标签形成可辨认的“生命感”，但不冒充人类或复制既有角色。它不持有发送、批准、拒绝、停止 Hermes、接管控制或其他授权能力；一切高风险操作始终由独立的可访问控件完成。

基础视觉 token 固定以下语义，不允许页面各自挑色：深墨黑背景、石墨蓝表面、灰蓝结构线、暖白正文、低饱和灰蓝次要文字、蓝青“信号/在线”、琥珀“需要用户介入”、红色“危险/拒绝/失败”。蓝青不能装饰性铺满页面，红色不能表示普通离线；状态还必须同时具有文字、图标或几何变化。正文使用系统人文无衬线字体，opaque ID、sequence、时间和诊断值才使用等宽字体。

禁止把大面积玻璃拟态、每个容器都做悬浮卡片、随机粒子、假终端字符、通用机器人素材或与真实 Hermes 状态无关的“思考中”动画当成产品风格。辉光、渐变和轨道只能作为 SignalCore 的有界状态语言；装饰效果在去除后不能改变信息含义，任何活动指示都必须由规范事件或本地可证明状态驱动。

主界面包含：

- 顶部助手身份、当前 backend/Profile、conversation、连接和执行主机；
- 中央原创 SignalCore 状态主体；
- 录音波形和转写确认区；
- 按用户轮次聚合的完整 Hermes 回复和可折叠工具轨迹；
- 独立、高对比度审批面板；
- 连接、语音、视觉、安全和诊断设置。

桌面采用“导航/会话工作台/状态与操作”信息层级。SignalCore 长期驻留在会话工作台的视觉安全区，不随消息滚动，不覆盖可选择文字、工具轨迹或操作控件；常规目标尺寸约 220–260 px。录音时可进一步展开，实时转写、停止并转写和取消录音保持无遮挡。

手机按任务优先级压成单列，不得只是同比缩小桌面界面。核心待机时位于会话标题下方，目标尺寸约 156–184 px；录音时可展开为中央交互区域，实时转写位于其下方。审批、澄清和发送确认出现时，核心退让首要操作区域。

信号生命核心使用以下规范状态：

| 状态 | 视觉陈述 |
| --- | --- |
| 待机 | 低亮度、结构稳定，允许极慢偏心漂移 |
| 录音 | 核心展开；内层张合只由真实麦克风音量驱动 |
| 转写中 | 停止扩张，以窄扫描线表示本地可证明的转写阶段 |
| 等待确认 | 核心归位，保留稳定蓝青锚点 |
| 正在提交 | 结构收紧，方向轴锁定当前明确目标 |
| Agent 工作中 | 圆环错位运行，不显示虚构百分比或计时进度 |
| Agent 回复 | 仅由当前请求的规范文本事件产生轻微结构响应 |
| TTS 播放 | 仅由实际播放 segment 和音频包络驱动，不模拟口型 |
| 需要审批或澄清 | 使用琥珀状态并退让高对比操作面板 |
| `uncertain` | 环结构保持失配和悬停，不显示或播报成功、完成或安全重试 |
| 失败 | 短红色断裂脉冲后停留为可读静态失败状态 |
| 完成 | 一次短暂闭合后回落待机，不持续庆祝 |

完整回复、字幕、工具事件和审批面板始终是信息权威。信号生命核心不得替代状态文字，不得根据无对应事实的本地计时器制造“正在思考”、成功、失败或完成。用户开始录音时可以中止 TTS 的视觉响应，但不得表现为 Agent 已被中断。

必须支持减少动态效果、高对比度、系统字号和键盘/读屏访问。shader、Rive 或高帧率失败时回落到静态图形，不能影响文字和审批。任何页面进入功能实现前，先在组件目录覆盖 normal、hover/focus、disabled、loading、empty、error、approval 和 uncertain；再以手机/桌面 golden、最大字号和 Flutter accessibility guideline 作为视觉合并门。

## 7. 非功能目标

### 7.1 延迟预算

| 阶段 | 目标 |
| --- | --- |
| 结束说话 → final transcript | P50 ≤ 1.0 s，P95 ≤ 2.5 s |
| 本地 command → accepted | ≤ 100 ms |
| 远程 command → accepted | P50 ≤ 300 ms（正常网络） |
| Gateway event → 在线 UI | P50 ≤ 100 ms，P95 ≤ 250 ms |
| 稳定首句 → 热 TTS 首段 | P50 ≤ 1.0 s，P95 ≤ 2.5 s |
| 用户操作 → TTS 停止 | ≤ 300 ms |

这些指标不包含 Agent 思考和工具运行。无法达成时记录实测，不隐藏等待或伪造进度。

STT 与 TTS 延迟目标适用于完成 M3 capability benchmark 的推荐本地配置；设备/模型组合必须记录为具名 profile。仅 CPU 的本地 TTS 若合成成功但热首段超出目标，必须标为 `text-first degraded`，默认自动播报保持关闭且完整回复、手动文字流程和播放停止门继续可用；它不能被宣称为达到推荐语音性能，也不阻止同一客户端在合格加速配置上启用播报。该降级口径不修改上述推荐目标；后续发行矩阵仍须在具名推荐设备上通过目标。

### 7.2 稳定性

- 50 次端到端循环中客户端自身成功率 ≥ 95%；
- Hermes 同一真实 session 连续 10 轮不串线；
- 单个外部服务崩溃或超时不导致 Client/Gateway 退出；
- 客户端重启不会自动执行未完成请求；
- 重复 event ID 安全忽略，sequence 缺口可检测和恢复；
- 任一语音环节失败仍能查看完整回复；
- Profile、backend 或 conversation 切换不会串用凭据、历史、活动 request 或 TTS；
- 长 conversation 的请求大小受硬预算限制，历史增长不使每轮请求和 SQLite 写入无界增长。

### 7.3 性能与可访问性

- 中档移动设备以稳定 60 FPS 为目标；桌面可选 60/120 FPS；
- idle、完成、失败、低电量、后台恢复和减少动态效果模式停止无必要的持续 ticker；活动状态才使用持续动画；
- 真实 HomeScreen 以 500 条桌面历史和 2,000 条手机历史验证列表虚拟化，不一次构建全部事件；
- delta、录音电平、TTS 包络和 shader 同时更新时分别记录 build/raster/总帧时间与 RSS；长音频包络不得在 UI isolate 同步全量扫描；
- 无快速闪烁、持续抖动或必须依赖颜色才能理解的状态；
- 视觉性能与语音/网络延迟分别测量。

## 8. 非协商安全约束

- 不自动批准 Agent 权限、澄清、秘密、sudo、删除、发布、付款或授权请求；
- 不静默重试提交状态不明的命令；
- 不把 Hermes endpoint 或未认证 Agent 服务直接暴露公网；
- 原始音频默认不离开录制设备；
- Client 不获得任意文件、任意子进程或原始管理密钥能力；
- 所有远程连接使用有效 TLS 或明确固定证书；
- 每台设备独立凭据，可单独撤销并采用最小 scope；
- 日志和诊断不得包含可用密钥、认证头或未经脱敏的秘密；
- Agent 原有沙箱、审批和权限体系始终保留；
- 凭据只可由与其绑定的 Provider/Profile 使用，改变 origin/认证身份不得继承旧 key；
- 不跨 conversation 或 Provider 静默发送历史、记忆、摘要或部分回复；
- 文本确认必须绑定发送目标，目标变化必须重新确认。

## 9. 明确不做

当前基线不包含：

- GPT Live 式持续全双工音频；
- 默认后台持续监听或唤醒词；
- 控制任意桌面应用当前 UI 会话；
- 由项目运营的公共中转云；
- Agent 未经设备授权直接控制 Client 设备；
- 自动训练、购买或管理 STT/TTS 模型；
- 多人共同编辑同一 prompt 的 CRDT；
- 多用户组织、共享审批或公共租户；
- 未经独立规格和验收门定义的附件上传；
- 为视觉效果绕过可访问性或安全确认。
- Codex、OpenClaw 或任意通用 Agent 插件的产品接入与发行；
- 在没有用户预览和确认时自动把 Direct LLM 对话、记忆或摘要迁移到 Hermes/另一 Provider；
- 让 LLM 自动选择、切换或授权 Hermes 工作目标。
