# VoxHandoff 产品规格（v2：Hermes 移动端人格化交互层）

> 基线日期：2026-08-16。本版为重新定位后的需求基线；旧版"完整 Agent
> 控制面"规格已归档至 `spec/archive/2026-08-16-full-agent/`，作为未来
> 升级路径参考，不再是当前需求来源。

## 1. 产品定义

VoxHandoff 是面向 Hermes 用户的**移动端人格化语音交互层**：一个可命名、
可塑造人格、可选择声音、可管理记忆的私人助手前端。它不重新发明 Agent
后端——Agent 能力属于 Hermes；VoxHandoff 负责"人"与"界面"这一侧：
录音、转写确认、聊天、播放、记忆、人格与视觉呈现。

核心体验是自然、连续、可打断的分轮语音对话：看得见当前目标，能编辑和
确认文字，能停止播报，任何语音故障都不丢文字。用户开口默认只打断 TTS；
不承诺后台常听、唤醒词或持续全双工。

VoxHandoff 不是新的 Agent 框架、不是公共模型中转、不是遥控器壳——它是
**人格化前端**：同一助手身份贯穿聊天与可用的 Hermes 工作能力，差异化的
护城河在人格、声音、记忆策略和 SignalCore 视觉，不在 Agent 后端。

### 1.1 目标用户与成功标准

目标用户是希望用手机长期使用一个私人语音助手、同时保留 Hermes 作为真正
Agent 后端的个人用户。产品成功至少意味着：

- 助手身份、人格、声音、记忆和视觉保持连续，能稳定陪伴；
- 每轮发送前都能看见并确认文字与实际目标，切换目标不会沿用旧确认；
- 日常聊天走 Direct LLM（无需启动 Hermes）；需要时可通过 Hermes 对话接口
  获得工作能力，看到真实回复；
- 长期聊天不无限发送全部历史，记忆可查看、编辑、删除；
- 任一外部服务或语音环节失败时，已确认文本、已收到回复仍然可用。

## 2. 支持范围

### 2.1 平台

- Android（当前优先，v0.1.0 目标平台）；
- iOS（后续）；
- macOS / Windows（后续桌面适配，共享同一 Flutter 代码库）；
- Linux 不作为客户端，仅作服务端/STT 部署主机。

移动端第一版只承诺前台按键说话，不承诺后台常听或自定义唤醒词。

### 2.2 后端能力边界（v0.1.0）

| 能力 | 来源 | 状态 |
| --- | --- | --- |
| 纯聊天/陪伴 | Direct LLM Provider Profile（OpenAI-compatible chat API） | v0.1.0 主链路 |
| Hermes 工作对话 | Hermes 自身 API（chat/completions 或等价对话接口） | v0.1.0 可选，需配置 |
| 工具/任务/审批深度集成 | 旧 Gateway/Node 控制面 | **冻结**，等 Hermes 上游补齐 run 幂等与 approval ID 后作为升级路径，非 v0.1.0 |

Direct LLM Profile：用户自接的 OpenAI-compatible API 负责纯聊天或陪伴；API key
只保存在本机 OS 安全存储，与不可变 Profile ID 绑定；默认不上传录音，只有绑定
目标快照的已确认文本才发送。该来源没有 Agent host、tool event、approval 或
跨设备 command 语义。

Hermes 对话：通过 Hermes 自身的对话/API 能力接入；不重新建立独立的
Gateway/PostgreSQL/Connector 控制面（旧实现已归档冻结）。Hermes 工具审批等
深度语义按 Hermes 上游能力现状处理，v0.1.0 不承诺手机端审批面板。

### 2.3 部署形态

- 单机自用：手机 app + 用户配置的 LLM API / Hermes 对话接口；
- STT/TTS 可本地（faster-whisper / Piper / GSV）或用户同意的远程 provider；
- 不运营公共中转云；所有远程部署由用户控制。

## 3. 统一个人助手体验

### 3.1 Assistant Profile

产品至少有一个当前启用的 `AssistantProfile`，语义由稳定 `assistantId` 关联：

| 配置域 | 最小内容 |
| --- | --- |
| 身份与人格 | 名称、人格描述、系统提示、首选语言 |
| 记忆 | 记忆策略、固定记忆、滚动摘要设置、删除与导出策略 |
| 语音输入 | STT Profile、语言、麦克风、远程上传同意引用 |
| 语音输出 | TTS Profile、音色、语速、语言、自动播报策略 |
| 交互 | 用户开口时的 TTS 打断、通知策略 |
| 视觉 | SignalCore 主题、动态强度、减少动态覆盖 |
| 后端 | 默认聊天 Backend Profile、可选 Hermes 对话配置 |

`AssistantProfile` 不保存 API key、token、私钥或凭据；有单调
`assistantRevision`，人格/策略变化递增并撤销旧确认。首版只要求一个活动助手。

### 3.2 能力而不是多个产品

- 基础会话、草稿、人格、记忆、声音、SignalCore 使用同一套界面语义；
- 每一轮仍显示实际 backend 与隐私目标，不隐藏数据发往哪里；
- Direct LLM 只提供聊天 capability；Hermes 对话在配置后提供聊天+工作能力；
- 切换 backend 不是隐式路由：显示将发送的确认文本与目标，并要求新确认；
- Hermes 工作结果可成为会话一部分，但工具事实/审批/执行主机不能被压成
  普通 LLM 文本或由 LLM 伪造（不展示即不展示，不冒充）。

### 3.3 Provider Profile、凭据与会话隔离

- `providerProfileId` 是 opaque、不可变的服务商/凭据边界；修改 origin/auth
  必须新建 Profile，不原地复用；
- 同一 Profile 内用户明确声明的 key rotation 才可替换凭据并递增
  `credentialRevision`，使旧确认失效；空 key 只在身份与 revision 未变时表示
  "保留现有 key"；
- `conversationId` 是历史与上下文边界；每 conversation 固定 assistantId、
  backend kind 与 backend target；切换 backend/模型默认新 conversation；
- 删除 Profile 先阻止新请求，再让用户选择保留/导出/删除历史。

### 3.4 长期记忆与上下文

- 每 conversation 独立历史与单调 `contextSnapshotRevision`；任何改变下一请求
  payload 的事实都递增 revision 并撤销旧确认；
- 最小上下文组合：助手系统提示 → 显式允许的固定记忆 → 滚动摘要 → 预算内
  最近完整轮次；
- 部分/取消/失败/不完整回复不进后续可信上下文；
- 记忆默认保存在当前设备；未来同步前须单独定义加密、授权、删除与可见范围。

## 4. 核心用户流程

### 4.1 首次配置

1. 创建/恢复 Assistant Profile（名称、人格、语言、记忆、SignalCore）；
2. 配置 Direct LLM Provider Profile（可选）与 Hermes 对话接口（可选）；
3. 配置 STT/TTS Profile，分别测试录音、识别、聊天、播放；
4. 选择默认聊天后端、会话、麦克风、声音、语速、播报策略。

错误必须指出失败环节，不使用无法行动的"请求失败"。

### 4.2 发起请求

1. 按住说话或点击录音；
2. 显示麦克风占用与音量；
3. 流式 STT 显示临时字幕；
4. 结束录音后生成 final transcript；
5. 用户修改、取消或确认；确认生成不可变文本 revision 与目标快照；
6. 显示当前助手、backend、conversation/Profile；
7. 发送到 Direct LLM / Hermes 对话接口；
8. 流式更新回复；
9. 回复按明确终态持久化；只有 `completed` 可触发完成式 TTS；
10. 可停止播报，可继续文字阅读。

确认快照至少绑定：normalized `confirmedText`、draft ID/revision、text hash、
`assistantId`、`assistantRevision`、conversation 的 context revision/hash、
ChatSource、`conversationId` 与 backend target revision；Direct LLM 额外绑定
`providerProfileId`、credential/configuration revision、origin 与 model。
任一权威值变化使确认失效并回到可编辑草稿。

发送前目标离线时保留为草稿，恢复后必须再次确认，不自动排队。

### 4.3 实时反馈

- 即时确认：本地动画/提示音/"收到"等确定性短句，不声称任务开始/完成；
- 工作反馈：只根据真实事件说明阶段（聊天流、TTS 播放），不生成虚构百分比；
- 回答播报：从完整文字安全切分稳定句，过滤代码/日志/长路径/表格/秘密。

用户开始说话默认只停止 TTS。

### 4.4 审批与澄清（v0.1.0 边界）

手机端不承诺完整审批面板。若 Hermes 对话产生需要审批的工作，产品行为是：
明确显示"需要用户在 Hermes 端处理"，不伪造审批通过、不静默跳过、不自动
批准任何权限/删除/发布/付款/授权请求。

## 5. 功能需求

### 5.1 录音与 STT

- 支持按住说话与点击开始/结束；
- 录音、权限拒绝、静音、设备断开、格式错误分别报告；
- provisional 与 final transcript 区分；final 可编辑并保留原识别版本用于
  本地诊断；
- 原始录音在 final 产生或取消后立即删除；失败残留最多 24 小时；
- STT/TTS 是独立配置端口；项目不内置模型/音色/云端账号生命周期；
- 免费默认预设：本地 faster-whisper（或用户同意的远程 HTTPS provider）；
  设置页只探测 readiness，不下载模型；
- 远程 STT 默认关闭；启用时显示音频将离开设备、目标服务、TLS 状态与已知
  保留策略，并取得显式同意；origin/TLS/保留变化须重新确认；
- 没有 STT 时仍可文字输入使用全部功能。

### 5.2 Direct LLM conversation 与消息终态

- 一 Profile 多 conversation；历史按 conversationId 隔离；
- 每轮只发送预算器选中的上下文，不无界发送全部历史；
- 流式 delta 实时显示，数据库合并写入；每条 message 最多每 250 ms 刷盘，
  terminal 到达立即写终态；
- 请求与响应有硬字节上限、deadline、取消；非 2xx 有界读取；
- 切换 Profile/conversation 前先显式取消当前请求并写 `cancelled`；
- 终态互斥：`streaming` / `completed` / `cancelled` / `failed` /
  `incomplete` / `truncated`；只有 `completed` 触发完成式 TTS、摘要与默认
  后续上下文。

### 5.3 完整回复与语音回复

- 保存两类独立内容：完整回复（原始文字/结构化事件）与播报文本（稳定短句）；
- 播报顺序：Agent 明确摘要 → 稳定自然语言句 → 确定性规则提取 → 可选摘要
  模型 → 无法安全摘要时只播报状态并提示看文字；
- 摘要/TTS 失败不得修改、覆盖或延迟完整回复。

### 5.4 TTS

- provider-neutral port；Piper-compatible 本地服务为免费默认，GPT-SoVITS
  等为可选配置；
- 支持预热、分段生成、播放队列、取消；第 N 段播放时可并行生成 N+1 段；
- 每段绑定 request、message revision、segment index；过期/中断/切换段不播放；
- 用户开始录音或点击停止后 300 ms 内停止/淡出；
- TTS 离线降级为字幕，不阻塞聊天；
- 可配置 provider/音色/语速/语言/自动播报；不支持的字段隐藏或标不可用；
- 远程 TTS 首次发送回复文字前说明并取得同意。

### 5.5 设置与诊断

- Direct LLM / Hermes 对话 / STT / TTS 独立连接测试；
- 助手人格/记忆/backend/麦克风/语言/音色/语速/播报/动态效果设置；
- OS 安全存储保存密钥，普通库只保存引用；
- 诊断导出前预览，认证头/令牌/密钥/敏感 payload 脱敏；
- 显示组件版本、当前连接、最近失败阶段；
- 不提供永久忽略 TLS 错误的普通选项。

### 5.6 数据生命周期

| 数据 | 默认位置 | 默认保留 |
| --- | --- | --- |
| 原始录音/临时音频 | 录制设备私有临时区 | final/cancel 后立即删除；失败残留 ≤24h |
| 原始 transcript | 录制设备本地库 | 7 天，可立即删除或关闭 |
| Direct LLM 对话与终态 | 配置该 Provider 的设备本地库 | 保留至用户按 conversation/Profile 删除 |
| 固定记忆与滚动摘要 | 当前设备本地库 | 保留至用户编辑/删除 |
| TTS 缓存 | 播放设备本地缓存 | 应用退出或 24h |
| 无正文诊断与阶段指标 | 本地诊断库 | 7 天 |

删除同步历史写 tombstone 停止分发，再清内容；备份残留由部署者配置并展示。

## 6. 视觉与交互规格

沿用并保留 **SignalCore** 作为原创视觉主体（详见归档规格第 6 节；本版不
变更视觉语言）：深墨黑背景、石墨蓝表面、灰蓝结构线、暖白正文、蓝青信号、
琥珀介入、红色危险；状态同时有文字/图标/几何变化；禁止玻璃拟态铺满、
悬浮卡片堆砌、随机粒子、假终端、通用机器人素材。

手机单列布局，待机核心约 156–184 px，录音可展开为中央交互区；审批/确认
出现时核心退让首要操作区。SignalCore 状态机（待机/录音/转写中/等待确认/
提交/工作中/回复/TTS/uncertain/失败/完成）与"完整回复/字幕是信息权威"
原则不变。支持减少动态、高对比度、系统字号、读屏；shader 失败回落静态图形。

## 7. 非功能目标

### 7.1 延迟预算

| 阶段 | 目标 |
| --- | --- |
| 结束说话 → final transcript | P50 ≤ 1.0 s，P95 ≤ 2.5 s |
| 已确认文本 → 本地接口 accepted | ≤ 100 ms |
| 远程 API → 首 token | P50 ≤ 1.0 s（正常网络） |
| 稳定首句 → 热 TTS 首段 | P50 ≤ 1.0 s，P95 ≤ 2.5 s |
| 用户操作 → TTS 停止 | ≤ 300 ms |

指标不含 Agent 思考与工具运行；无法达成记录实测，不隐藏等待。

### 7.2 稳定性

- 50 次端到端循环客户端自身成功率 ≥ 95%；
- Direct LLM 连续 10 轮不串线；
- 单个外部服务崩溃/超时不导致 app 退出；
- 重启不自动执行未完成请求；
- 任一语音环节失败仍能查看完整回复；
- Profile/backend/conversation 切换不串凭据、历史、活动 request 或 TTS；
- 长 conversation 请求大小受硬预算限制。

### 7.3 性能与可访问性

- 中档移动设备稳定 60 FPS；减少动态模式停止非必要 ticker；
- 2,000 条手机历史验证列表虚拟化；
- 无快速闪烁/持续抖动/仅颜色区分；视觉性能与语音/网络延迟分别测量。

## 8. 非协商安全约束

- 不自动批准 Agent 权限、澄清、秘密、sudo、删除、发布、付款或授权请求；
- 不静默重试提交状态不明的命令；
- 不把未认证服务直接暴露公网；
- 原始音频默认不离开录制设备；
- Client 不获得任意文件/任意子进程/原始管理密钥能力；
- 所有远程连接使用有效 TLS 或明确固定证书；
- 每台设备独立凭据，可单独撤销，最小 scope；
- 日志与诊断不包含可用密钥、认证头或未脱敏秘密；
- 凭据只可由绑定 Profile 使用，改变 origin/auth 不得继承旧 key；
- 不跨 conversation/Provider 静默发送历史、记忆、摘要或部分回复；
- 文本确认绑定发送目标，目标变化必须重新确认。

## 9. 明确不做（v0.1.0）

- 自建 Gateway/PostgreSQL/Node 控制面作为主线（冻结为升级路径）；
- 手机端完整 Hermes 审批面板（显示"需在 Hermes 端处理"）；
- GPT Live 式持续全双工音频；
- 默认后台持续监听或唤醒词；
- 控制任意桌面应用当前 UI 会话；
- 项目运营的公共中转云；
- 自动训练/购买/管理 STT/TTS 模型；
- 多用户组织、共享审批、公共租户；
- 未定义规格与验收门的附件上传；
- 为视觉绕过可访问性或安全确认；
- 任何通用 Agent 插件的产品接入与发行；
- 未经预览确认自动迁移对话/记忆到另一 Provider。
