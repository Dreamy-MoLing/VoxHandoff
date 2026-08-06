# VoxHandoff 正式开发基线

> 基线版本：1.62<br>
> 生效日期：2026-08-06<br>
> 状态：Archived / Frozen

> 归档说明：VoxHandoff 已停止后续产品开发。本目录保留原产品、架构和
> 验收基线作为工程记录；其中“下一轮开发”“后续开发批次”等文字均是
> 历史快照，不再代表当前执行计划。当前入口与归档结论见根目录
> [`README.md`](../README.md)。Hermes Agent v0.20.0 已在上游提供本项目
> 原本要补齐的核心 GUI 语音能力，详见其
> [官方发布说明](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.8.3)。

在项目开发期间，本目录是 VoxHandoff 唯一有效的产品与工程基线。归档后它作为冻结的历史基线，供理解实现、评审记录和验收证据使用：

1. [`PRODUCT.md`](PRODUCT.md)：回答“为谁做、用户得到什么、哪些行为必须成立”，是用户需求和可观察验收的权威来源；
2. [`ARCHITECTURE.md`](ARCHITECTURE.md)：回答“状态与数据由谁拥有、跨边界如何保持安全一致”，是目标模型、生命周期、协议和信任边界的权威来源；
3. [`DELIVERY.md`](DELIVERY.md)：回答“仓库现在实际做到哪里、证据是什么、下一批具体做什么”，是阶段状态、PR/CI、发布阻断和执行顺序的权威来源。

归档前的开发工作按上述顺序读取，并从 `DELIVERY.md` 的“当前快照 → 已确认差异 → 后续开发批次”进入工作。`PRODUCT.md` 与 `ARCHITECTURE.md` 描述当时必须达到的行为；不能仅凭其中的目标态推断代码已经实现。实现状态由 `DELIVERY.md` 中分层证据确认。

证据按互不替代的轴记录：源码存在；本地自动化；远端 CI；真实服务/真实数据库；人工 GUI/实体设备；发布汇总门。它们不是一条可相互推导的等级链：CI 不能证明实体麦克风，真实服务 adapter 不能证明 GUI，本地门不能写成 GitHub Actions，直接 Hermes PoC 不能写成 Gateway/PostgreSQL 纵向链路。发布门只在适用的各轴证据都绑定同一候选版本后关闭。

根目录 `docs/` 是前期分析输入，已经完成吸收和冲突消解。它不再是需求来源，不得在代码注释、Issue、测试或新文档中引用；如它与本目录冲突，以本目录为准。

这里约束的是可观察功能、数据/权限边界、兼容语义和验收结果，不把尚未验证的 SDK、组件、目录布局或具体实现步骤固化成目的本身。文档允许在探索阶段存在实现空缺；开发可以先用小型 spike 和真实构建/测试选择路线，再在同一聚焦变更中把稳定结论、拒绝方案和退出路径回写本目录。任何实现自由都不得削弱下述非协商安全与一致性契约。

## 决策优先级

当实现遇到未覆盖情况，按以下顺序决策：

1. 数据不丢失、审批不绕过、命令不重复执行；
2. 用户能看见真实状态、完整回复和实际执行主机；
3. 官方协议与官方 SDK；
4. 活跃、成熟、五端可用且许可证可接受的社区方案；
5. 小型、版本化、可替换的自研适配层；
6. 视觉一致性和性能优化。

更改非协商安全约束、公共协议、权威数据模型或平台范围前，必须先修改本目录并记录理由、迁移方式和验收变化。普通实现选择可以由证据先行，但形成提交时规格、代码、测试和依赖记录必须一致；不得为了保持旧文字而保留已证伪或妨碍功能完成的方案。

## 修订记录

| 版本 | 日期 | 说明 |
| --- | --- | --- |
| 1.62 | 2026-08-06 | 归档 VoxHandoff：冻结产品/架构/交付基线，记录 Hermes Agent v0.20.0 上游能力重叠与停止后续开发的结论 |
| 1.61 | 2026-08-02 | 刷新批次 6 收口事实：PR #4 真实规模 54 commits / 214 files、head `3f3a3c0`、当前 CI 两组 run 全绿；修正 46/208 与 in_progress 旧文字；记录 review map 与剩余未关门 |
| 1.60 | 2026-08-01 | 重新确立统一个人助手产品基线；按当前代码与 PR #4 复核 Provider/凭据/历史隔离、确认目标绑定、Direct LLM 生命周期/终态/有界读取、长期上下文、语音配置与 H1 外部能力门，并给出 Luna Max 可直接执行的开发批次 |
| 1.59 | 2026-07-31 | M5 真实服务证据：OpenRouter `/api/v1` 免费模型十轮 SSE、取消与离线门；官方 Piper loopback adapter 与 faster-whisper JSONL 合成音频链通过，明确保留物理麦克风 GUI 发行验收边界 |
| 1.58 | 2026-07-31 | M5 设置增量：来源设置页将 Hermes 状态、Direct LLM、faster-whisper readiness 与 Piper 本机 HTTP 配置/测试隔离；Piper 固定官方 `/info` 与 `/synthesize` 契约、精确 loopback 限制与失败降级，Flutter 门扩至 178 项；真实用户服务 smoke 仍未关闭 |
| 1.57 | 2026-07-31 | M5 首个可审查增量：新增本机 direct LLM 的 HTTPS/SSE、OS 安全存储 key、本机 Drift 历史、取消与文字优先 UI；离线/Flutter 门通过，真实用户 provider 与音频端口 smoke 仍待显式配置后执行 |
| 1.56 | 2026-07-31 | 将解耦列入 M5 的结构治理阶段：先完成最小语音聊天闭环，再以契约测试保护的增量方式拆分 UI、配置、Connector 与 Gateway 账本，不进行阻塞功能交付的大重写 |
| 1.55 | 2026-07-31 | 收敛为 GUI 优先的语音聊天/数字伙伴 MVP：Hermes 保持唯一 Agent，新增用户自带 LLM API 的直接文本对话边界；STT/TTS 改为用户可配置端口并给出免费开源默认预设，近期交付改为先打通可用体验 |
| 1.54 | 2026-07-29 | 固化 Hermes 0.19 真实 10 轮/stop/manual deny/SIGKILL/restart 证据与幂等能力阻断；关闭 Fedora Flutter 170 测试、Linux release 和 2,000 事件 HomeScreen 60 Hz 门 |
| 1.53 | 2026-07-26 | 收缩为 Hermes-only MVP，暂停 Codex/OpenClaw 与发行工作；新增生产 Connector、保守能力/恢复契约、轮次聚合、SignalCore 和真实 HomeScreen 性能门 |
| 1.52 | 2026-07-22 | 完成 M3 录音/本地与远程 STT 同意边界、终稿确认、GPT-SoVITS 分段播报与可打断播放，并记录 CPU/base profile 的 30/30/50 降级实测 |
| 1.51 | 2026-07-22 | 完成 M2 目录/会话协议、Flutter 生产文字工作区、双客户端 cursor 恢复、Linux Secret Service 真读写与五平台构建门 |
| 1.50 | 2026-07-22 | 正式产品名定为 VoxHandoff；保留既有协议、签名 domain、package scope 与应用 ID 作为兼容标识 |
| 1.49 | 2026-07-21 | 增补 request route 与 replay 批次协议，落地中央 frame router、未知 request 恢复和启动 cursor replay |
| 1.48 | 2026-07-21 | 区分绑定契约与可替换实现假设，落地 Drift 原子账本、跨设备 origin route 与本地提交恢复状态 |
| 1.47 | 2026-07-19 | 建立客户端协议隔离事件模型、身份/序列收敛器、缺口 replay 与持久化后精确 Ack 门 |
| 1.46 | 2026-07-19 | 建立 Flutter 认证 Gateway 双向流、有限握手门、协议身份校验与 schema hash 漂移门 |
| 1.45 | 2026-07-19 | 增加 active device credential 安全索引、重启发现与冲突 fail-closed 门 |
| 1.44 | 2026-07-19 | 接通 Riverpod 配对 workflow 与原创手动链路面板，增加全状态交互、手机/桌面 golden 和可访问性门 |
| 1.43 | 2026-07-19 | 增加 Flutter Gateway TLS channel factory、显式 CA 导入和明文降级拒绝门 |
| 1.42 | 2026-07-19 | 为 Confirm 显式恢复增加短时内存精确响应缓存、并发合并与凭据 hash 复核门 |
| 1.41 | 2026-07-19 | 接通客户端配对 gRPC 适配层、结构化 Gateway 错误码与无自动重试的 uncertain 传输语义 |
| 1.40 | 2026-07-19 | 接入五平台 OS 安全存储适配、严格秘密记录 codec 与平台备份/Keychain 配置门 |
| 1.39 | 2026-07-19 | 固定客户端配对状态机、秘密隔离、显式 uncertain 恢复与密钥 pending-to-active 提升门 |
| 1.38 | 2026-07-19 | 增加客户端待签载荷本地解析/重建门，并固定五平台 Ed25519/SHA-256 实现依赖 |
| 1.37 | 2026-07-18 | 统一中央视觉为原创信号镜，移除与非拟人视觉约束冲突的 AI 眼睛表述 |
| 1.36 | 2026-07-18 | 增加 Dart 端全部设备签名 framing helper 与 TypeScript 固定字节一致性门 |
| 1.35 | 2026-07-18 | 固定 Flutter/Dart 工具链与依赖证据，建立五平台安全客户端 shell，并确立原创非模板化视觉与组件验收门 |
| 1.34 | 2026-07-18 | 以真实 PostgreSQL 和双向流组合验收重连、重复、乱序、Gateway 重建收敛并关闭 M1 |
| 1.33 | 2026-07-18 | 实现本机 owner 恢复的独立持钥证明、旧凭据族原子撤销和新 owner 激活 |
| 1.32 | 2026-07-18 | 实现无公网 RPC 的初始 owner 本机引导、密钥持有证明与 PostgreSQL 单实例门 |
| 1.31 | 2026-07-18 | 强制 Approval 绑定设备/credential/Node/audience/摘要/决定签名与事务 nonce |
| 1.30 | 2026-07-18 | 接通 PostgreSQL access identity、逐帧 generation 复核与证书验证的 HTTPS PairingService |
| 1.29 | 2026-07-18 | 实现 refresh 单次轮换/签名重放撤销与管理员签名设备撤销的耐久路径 |
| 1.28 | 2026-07-18 | 增加 pairing/credential/nonce/rate-limit forward migration 与真实 PostgreSQL 重建验收 |
| 1.27 | 2026-07-18 | 实现事务化配对 Begin/Inspect/Approve/Complete/Confirm 状态机与离线并发/过期验收 |
| 1.26 | 2026-07-18 | 实现跨客户端确定性签名 payload、Ed25519 SPKI 校验、CSPRNG 和 HTTPS audience 原语 |
| 1.25 | 2026-07-18 | 固定配对 owner 核验、双阶段密钥证明、token 轮换/重放和高风险设备签名 wire contract |
| 1.24 | 2026-07-18 | 接通 PostgreSQL event outbox pump 与有界 live Client 流，慢消费者以耐久 replay 恢复 |
| 1.23 | 2026-07-18 | 接通 clarification pending/expiry/confirmed-text/outbox，使用 send scope 且与 approve 权限隔离 |
| 1.22 | 2026-07-18 | 接通耐久 approval pending/CAS/expiry/audit/dispatch，禁止摘要替换、迟到或并发重复决定 |
| 1.21 | 2026-07-18 | 建立交互控制命令账本并接通显式 interrupt 的 lease/scope/idempotency/outbox 路径 |
| 1.20 | 2026-07-18 | 接通 Node 注册、固定 dispatch、Ack/失败和单调事件入账，拒绝旧连接与乱序事件 |
| 1.19 | 2026-07-18 | 接通 send/lease/GetRequest/replay/Ack 账本路径，并保存完整失败分类 |
| 1.18 | 2026-07-18 | 建立认证后 Client/Node gRPC 双向流、握手门、逐帧撤销复核与 TLS/loopback 边界 |
| 1.17 | 2026-07-18 | 固定 control lease CAS/显式接管/审计，并以 forward migration 统一审批 `rejected` 状态 |
| 1.16 | 2026-07-18 | 建立 PostgreSQL acceptance/sequence/outbox 同事务账本与真实集成门 |
| 1.15 | 2026-07-18 | 固定 Client 预生成 request identity，使 acceptance 丢失后可查询而不重提 |
| 1.14 | 2026-07-18 | 建立 Buf 公共 schema、TS/Dart 生成、握手协商和协议一致性/兼容门 |
| 1.13 | 2026-07-18 | 固定 Hermes 非优雅断线到 `connection.lost`/uncertain 的真链路并关闭 M0 |
| 1.12 | 2026-07-18 | 固定隔离 Hermes 10 轮、stop、manual approval 与跨 gateway 重启恢复证据 |
| 1.11 | 2026-07-18 | 固定 Codex failure probe，并禁止非完成终态生成成功式语音摘要 |
| 1.10 | 2026-07-18 | 固定 Codex user-reviewed approval probe、阻塞和 interrupt 真链路证据 |
| 1.9 | 2026-07-18 | 增加 Codex 显式定时中断 PoC 和真链路 `request.interrupted` 证据 |
| 1.8 | 2026-07-18 | 记录 Codex 真链路规范 sequence 回归与修复证据 |
| 1.7 | 2026-07-18 | 固定 Hermes approval/stop idempotency、client recreation 和 Core failure/property 证据 |
| 1.6 | 2026-07-18 | 固定 Codex 可 fake 进程边界、server request 安全摘要和中断确认契约 |
| 1.5 | 2026-07-18 | 固定 Hermes SSE 事件大小、畸形 JSON 和错误正文隔离边界 |
| 1.4 | 2026-07-18 | 固定统一 event、capability、failure taxonomy 与终态推导规则 |
| 1.3 | 2026-07-18 | 建立 repository consistency check 与固定版本、最小权限 CI 门 |
| 1.2 | 2026-07-18 | 增加仓库级资产、攻击者、信任边界、攻击故事和严重度校准 |
| 1.1 | 2026-07-18 | 固定部署权威、离线命令、配对/审批、数据生命周期、协议兼容、版本治理和 benchmark 口径 |
| 1.0 | 2026-07-18 | 初始产品、架构与交付基线 |
