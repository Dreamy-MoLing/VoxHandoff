# Agent Talk 开发与交付规范

## 1. 当前状态

基线日期环境：Fedora 44、Node.js 22.22.2、npm 10.9.7、Python 3.14.6、uv 0.11.26、Codex CLI 0.144.6、Hermes Agent 0.18.2、ffmpeg 8.1.2。

当前阶段：M0 协议核心。M-1 已完成；Codex interrupt 与 approval 真链路已固定，当前完成 Codex failure 注入和隔离 Hermes stop、approval、断线、重启真链路。

已完成：

- TypeScript workspace、strict 编译和 Node test 基线；
- dependency-free Agent Core：事件、capability、错误、状态机、短播报、脱敏；
- Core deterministic property/failure tests：taxonomy 唯一性、全 identity、bounded event dedupe、sequence gap、四类终态和语音失败隔离；
- Codex app-server stdio adapter；
- Codex fake stdio 契约：initialize、thread/turn、审批阻塞、诊断脱敏和 interrupt confirmation；
- Hermes HTTP/SSE adapter；
- CLI doctor、Codex/Hermes PoC 入口；
- Codex 当前安装版本的 12 项协议兼容检查；
- Codex 真链路新建线程、turn、delta、完成、进程重启和 thread resume；2026-07-18 `ready` 复测确认规范事件 sequence 连续为 1-4，同日 750 ms 受控中断复测确认 `request.accepted` sequence 1 后得到 `request.interrupted` sequence 2；
- Codex 真 approval probe：固定 `approvalPolicy=untrusted`、`approvalsReviewer=user`，确认 `approval.required` 可见、未发送 approval response，并以已确认 interrupt 结束；
- Hermes fake HTTP/SSE 契约测试、脱敏 fixture、事件大小上限、错误正文隔离、approval/stop idempotency 和 client recreation；
- 仓库级威胁模型：关键资产、攻击者、九条信任边界、重点攻击故事和严重度校准；
- repository consistency check 和最小权限 GitHub CI：locked install、check、offline tests。

未完成或未实测：

- Codex 显式 failure 真链路；
- 隔离环境内 Hermes 真链路 10 轮、stop、approval、重启；
- OpenClaw adapter；
- Protobuf/Buf 与 gRPC Gateway；
- PostgreSQL/PowerSync/Drift 同步；
- Flutter 五端客户端；
- STT、GPT-SoVITS 和音频播放真链路；
- 跨设备、远程网络、打包和发布测试。

Hermes Gateway 当前未运行，且现有 service definition 可能关联用户消息平台。未经隔离 profile 或明确确认，不得为了测试直接启动完整 gateway。

## 2. 仓库布局

```text
apps/
  poc-cli/              # 可重复协议/故障 PoC
  client/               # Flutter 五端客户端（待建）
packages/
  core/                 # 无外部依赖的领域模型和状态机
  adapters/             # Agent 原生协议适配器
  protocol/             # Protobuf/Buf schema 与生成入口（待建）
  sidecar/              # desktop stdio host（待建）
services/
  gateway/              # gRPC/HTTPS Gateway（待建）
  node/                 # Agent 主机 Connector（待建）
  stt/                  # Python STT sidecar（待建）
infra/
  postgres/             # migrations、seed、backup tests（待建）
  powersync/            # service/sync config（待建）
spec/                   # 唯一正式开发基线
scripts/                # 协议、质量与构建脚本
```

`docs/` 是已吸收的前期材料，不进入后续提交与引用。

## 3. 开发规则

### 3.1 通用

- 先修改 schema/领域模型和测试，再修改 transport/UI；
- 外部 payload 从 `unknown` 校验，禁止在协议边界使用 `any`；
- 错误必须包含 stage、稳定 code、是否可重试和脱敏 cause；
- 取消、失败、超时和 uncertain 分别测试；
- 依赖只有在明显改善正确性、五端覆盖或维护成本时加入；
- 版本写入 lockfile，升级单独评审 breaking change 和许可证；
- fixture/fake 测试离线运行，live test 显式开启且默认只读/低风险。
- 规格未覆盖的问题不得由实现默默决定；先在对应 `spec/` 文档写明选择、拒绝方案、迁移/回滚和验收影响。

### 3.2 TypeScript

- Node 22 基线，ESM，strict；
- Agent Core 不引入数据库、框架或 SDK 依赖；
- adapter 不把原生类型导出到 Core/UI；
- stdio stdout 只输出协议帧，stderr 只输出脱敏诊断；
- Codex binding 从安装版本临时生成，不提交大批版本特定文件。

### 3.3 Dart/Flutter

- 页面只消费 application/domain view model；
- Riverpod provider 不承载唯一耐久状态；
- platform plugin API 小型、版本化、可 fake；
- shader/Rive 失败必须有静态回退；
- 业务测试不依赖真实 GPU、麦克风、Keychain 或网络；
- 每个平台保留少量真实集成测试覆盖权限、安全存储和生命周期。

### 3.4 Python

- 使用 `uv` 锁定环境；
- STT 模型后端位于 adapter 后，协议不暴露 Python 对象；
- 模型缓存和下载目录显式配置；
- health 不等于模型 ready，必须区分 cold/loading/warm/failed；
- cancel、进程退出、显存不足和无音频都有稳定错误。

### 3.5 数据库

- PostgreSQL migration 只向前，生产数据不使用自动 destructive reset；
- event/request/idempotency 的唯一约束由数据库保证；
- outbox 与业务事实同事务；
- PowerSync sync rules 进入版本控制并做最小授权测试；
- Drift/PowerSync schema 变更做旧版本 Client 兼容和离线升级测试。

### 3.6 Git 与版本治理

- `main` 保持可构建、可测试；不在 `main` 上强制改写已提交历史，修正使用新提交或 `revert`；
- 提交采用 `feat:`、`fix:`、`spec:`、`test:`、`refactor:`、`build:`、`chore:` 等清晰前缀，一个提交只包含一个可解释、可回退的逻辑变化；
- 提交前至少运行与改动相关的 check/test，规格或脚本变化额外运行 repository consistency check；失败证据不得通过跳过测试隐藏；
- 自动化 Agent 可以在验证后创建聚焦的本地提交，但 push、PR、tag、发布和远程部署仍需明确授权；
- 产品发行使用 SemVer 和 annotated tag `vX.Y.Z`；首个公开稳定协议前保持 `0.y.z`，但任何已发布 wire/data breaking change 仍须提升 protocol major 并提供迁移说明；
- protocol major/minor、数据库 migration 序号和产品版本分别管理，不从显示版本推导兼容性；
- 每个发布 tag 对应变更记录、依赖/许可证快照、SBOM、migration/rollback 说明和已通过的发布门；
- 不提交 secret、`.env`、原始 live payload、原始录音、临时生成的 Codex binding 或设备专属产物。

## 4. 里程碑

### M-1 — 前期准备与基线治理（完成：2026-07-18）

目标：在扩展实现前，把安全、一致性、版本和验收问题变成明确契约。

- 固定 Embedded/Self-hosted/Hybrid 的耐久权威与迁移边界；
- 固定离线草稿、发送、acceptance、uncertain 和禁止自动重发语义；
- 固定 owner bootstrap、设备配对、scope、轮换、撤销和恢复流程；
- 固定 approval/control lease 状态机、并发和重启恢复；
- 固定数据分类、默认保留、删除、远程 STT 同意和附件范围；
- 固定 protocol 兼容窗口、滚动升级、Git/SemVer 和 benchmark 口径；
- 建立 repository consistency check、CI 入口和安全威胁模型；
- 创建已验证、可回退的 Git 基线。

退出条件：上述 P0 决策进入正式规格；本地统一质量命令可重复运行；威胁模型覆盖信任边界和高风险数据流；工作树在聚焦提交后保持干净。

### M0 — 协议核心完成

目标：把已有 PoC 提升为可依赖的 Agent 领域层。

- 完成 Codex interrupt、approval 和错误真链路；
- 在隔离 Hermes profile 完成 10 轮、stop、approval、断线和重启；
- 固定统一 capability/error/event taxonomy；
- 扩展状态机 property/failure tests；
- 保存脱敏协议 fixture 和阶段指标；
- `check`、`test`、`protocol:codex` 全绿。

退出条件：Codex/Hermes 不靠 UI 抓取完成可靠多轮；断线不重复提交；审批不丢失。

### M1 — 公共协议与 Gateway

目标：建立五端和远程 Node 都能依赖的耐久控制面。

- 创建 Protobuf/Buf schema，生成 TypeScript/Dart；
- 实现 gRPC Client/Node 双向流和 HTTPS 配对；
- PostgreSQL migrations、transactional outbox 和 sequence；
- 设备 identity/scope/control lease；
- live replay、gap、idempotency、uncertain 和吊销测试；
- 本地 embedded 模式可不开放固定端口。

退出条件：fake Client + fake Node 能在重连、重复、乱序、Gateway 重启后收敛。

### M2 — Flutter 文字客户端与同步

目标：先完成五端共享的文字 Agent 产品骨架。

- Flutter shell、Riverpod application layer 和 Fairy 静态核心；
- 登录/配对、Agent/会话选择、完整回复、工具事件和审批；
- gRPC live stream；
- PowerSync/Drift spike 与许可证/运维 gate；
- 一台桌面和一台手机观察、接管、断网和恢复；
- OS secure storage 五端真实测试。

退出条件：一桌面一手机对同一会话无重复、无串线，离线历史可读；若 PowerSync gate 失败，启动 cursor-sync fallback，不阻塞 UI。

### M3 — 语音闭环

目标：实现虚拟主播式可打断分轮对话。

- `record` AudioCapture adapter 和本地权限流程；
- Python streaming STT sidecar + remote STT adapter；
- final transcript 默认确认；
- GPT-SoVITS warmup、segment queue、`media_kit` 播放和 300 ms stop；
- 完整回复/播报/音频三个失败域；
- 30 条中文技术 STT、30 条 TTS、50 次端到端基准。

退出条件：达到 `PRODUCT.md` 延迟/成功率目标，或以实测经评审修订指标；语音失败不损伤文字链路。

### M4 — Fairy 动效与桌面能力

目标：在已经可靠的交互上增加原创角色表现。

- GLSL 核心、音频波纹、扫描线和短故障转场；
- Rive 辅助微动效；
- idle/recording/working/approval/completed/failed/uncertain 视觉状态；
- Windows/macOS/Linux 快捷键、托盘、通知和窗口行为；
- 减少动态效果、静态回退、60/120 FPS profile。

退出条件：shader/Rive 故障不影响使用；五端同状态语义一致；审批保持高对比度。

### M5 — OpenClaw、发行与运维

目标：完成第三个 Agent 和五端可交付构建。

- OpenClaw pairing/role/scope/event adapter；
- Tailscale/WireGuard、SSH tunnel 和 TLS reverse proxy runbook；
- Windows/Linux/macOS 安装包，Android/iOS 签名构建；
- Gateway backup/restore/upgrade/telemetry；
- SBOM、许可证清单、依赖和 secret scan；
- 平台 smoke、升级、崩溃恢复和撤销凭据测试。

退出条件：五端均可连接测试 Gateway 完成文字流程；支持的平台语音流程逐端验收；部署可备份、恢复和升级。

## 5. 测试矩阵

### 5.1 每次变更

- formatting/lint/type check；
- Core 和 adapter unit tests；
- Protobuf lint/generation/breaking check；
- 数据 migration 和 adapter contract tests；
- secret fixture 与日志脱敏测试。

### 5.2 合并前

- 相关 integration/failure injection；
- 旧版本数据库/协议兼容；
- 断线、乱序、重复、超时、取消和 uncertain；
- UI golden/accessibility tests；
- 依赖/许可证变更说明。

### 5.3 Nightly/设备实验室

- Windows、Linux、macOS、Android、iOS build + smoke；
- 真实安全存储写入/重启/读回/撤销；
- 麦克风权限、设备断开和音频播放中断；
- PostgreSQL/PowerSync/Gateway 重启和升级；
- Codex/Hermes/OpenClaw 允许版本的 live compatibility；
- 性能、内存、GPU、冷/热 STT/TTS 指标。

### 5.4 发布门

- 所有非协商安全测试通过；
- 无已知 Critical/High 可利用漏洞；
- SBOM 和第三方许可证清单完成；
- Gateway 数据备份和恢复演练通过；
- 设备凭据吊销后旧设备不可继续连接；
- TLS 错误 fail closed；
- 50 次端到端和各 Agent 10 轮验收通过；
- 安装、升级、卸载不删除未明确选择删除的用户数据。

### 5.5 可重复性能口径

- 每份结果记录 exact OS/build、CPU/GPU/RAM、设备型号、电源模式、组件版本、冷/热状态和网络 profile；“中档设备”在 M3/M4 gate 前必须替换为至少一台具名 Android 参考设备，不能仅凭开发机推断；
- local profile：RTT ≤ 2 ms、无人工丢包；normal remote profile：RTT 80 ms、jitter 20 ms、loss 0.5%、下行 20 Mbps、上行 5 Mbps；degraded profile：RTT 250 ms、jitter 50 ms、loss 2%；
- stage latency 的 P50/P95 至少采集 50 个成功样本，先做 5 次不计入的 warmup；cold start 另采至少 10 次并单独报告，不与 warm 数据合并；
- 50 次端到端成功率把 Client/Gateway/adapter/STT/TTS 导致的失败计入，把用户拒绝审批和 Agent 明确业务失败单列，不能从分母删除超时；
- 同进程阶段使用 monotonic clock；跨进程通过 trace ID 记录各自 monotonic duration，不用未校时的 wall clock 直接相减；
- 所有基准保存脱敏原始测量、汇总脚本和 pass/fail 结论；变更目标必须先修改 `PRODUCT.md` 并说明实测依据。

## 6. PoC 规范

PoC 是验收工具，不是一次性脚本。每次 live PoC 记录：

- OS、硬件、Agent/adapter/model 版本；
- 冷/热状态和网络环境；
- request/thread/turn 的脱敏关联；
- 每阶段开始/结束/耗时；
- 成功、失败、取消、uncertain；
- 日志中无秘密的证明；
- 与 gate 的明确通过/失败结论。

Live PoC 不得自动执行写文件、发消息、发布、删除或管理员动作。需要审批的测试使用临时目录、无害命令和明确人工批准。

## 7. 当前命令

```bash
npm install
npm run check
npm test
npm run protocol:codex
npm run poc -- doctor
```

显式 live PoC：

```bash
npm run poc -- codex --prompt "Reply with exactly: ready"
npm run poc -- codex \
  --prompt "Write a long numbered list. Do not use tools." \
  --interrupt-after-ms 750
npm run poc -- codex \
  --prompt "Use the terminal tool to run bash -lc 'exit 0'. Do not do anything else." \
  --approval-probe
npm run poc -- hermes \
  --base-url http://127.0.0.1:8642 \
  --token-env HERMES_API_KEY \
  --prompt "Reply with exactly: ready"
```

新工作区加入 Flutter、Buf、PostgreSQL 等工具后，在这里添加统一命令，不把关键检查藏在个人 IDE task 中。

## 8. 可观测性

每个请求至少记录：

- connection/conversation/request 的不可逆或本地 opaque ID；
- stage 与 duration；
- Agent/adapter/protocol version；
- accepted、first event、first stable sentence、first audio、completed；
- retry decision、sequence gap 和 failure code；
- 不记录默认正文、原始音频、认证头或密钥。

UI 不展示虚构完成百分比。诊断页面显示最后真实事件、同步状态、实际执行主机和是否可能仍在远端运行。

## 9. 风险登记

| 风险 | 当前处置 | 触发动作 |
| --- | --- | --- |
| Embedded 与同步模式语义分叉 | 两种账本实现共享 request/sequence/idempotency 契约 | 同一 failure fixture 结果不同即阻止 M1/M2 |
| 设备配对或撤销失效 | 单 owner、本机 bootstrap、短期 token、轮换和逐流撤销检查 | 未授权设备可建流或撤销后仍可操作即阻止发布 |
| approval 并发或迟到响应 | 耐久状态机、CAS、lease/scope 和 idempotency | 任一重复/迟到批准到达 Agent 即 Critical |
| Client 离线命令自动执行 | Client 只保存草稿，恢复连接必须重新确认 | 任何自动排空可执行命令即阻止发布 |
| protocol 滚动升级不兼容 | major/minor handshake、前一 minor fixtures、expand-first migration | N/N-1 组合失败即阻止升级 |
| 远程 STT 泄露音频 | 默认关闭、provider 同意、目标/TLS/保留提示 | 未确认上传或目标变化后继续上传即 Critical |
| Codex app-server 协议变化 | 当前版本生成 schema + 12 项兼容检查 | CI/live matrix 失败即阻止升级 |
| Hermes 真链路未验证 | fake SSE 已覆盖，完整 gateway 不擅自启动 | 建隔离 profile 后完成 M0 gate |
| PowerSync FSL 与 Drift beta | Sync Adapter 隔离 + contract test | 许可/稳定性失败切 cursor sync |
| 五端插件能力不一致 | record/media/security adapter + real device tests | 单平台失败显式降级或写原生 plugin |
| TTS 冷启动/崩溃 | 常驻预热、分段、纯文字降级 | 不达标时限制自动播报长度 |
| STT 技术词误识别 | 默认确认、高风险审批独立 | 30 条基准不达标切换后端 |
| 多设备重复提交 | DB uniqueness、idempotency、lease、uncertain | 任何重复执行为发布阻断 |
| 视觉耗电或不可访问 | 档位、减少动态、静态回退 | 中档设备不达标降低 shader 复杂度 |
| 远程高权限泄露 | device scope、TLS、Node 出站、Agent loopback | 安全门失败停止远程发布 |

## 10. Definition of Done

一项变更只有在以下条件全部满足时完成：

- 行为已在正式规格中存在，或规格随变更更新；
- 类型、lint、相关 unit/integration/contract test 通过；
- 错误能定位到具体 stage；
- 失败、取消和 uncertain 语义没有合并；
- 不引入明文秘密、静默重试或自动审批；
- 五端影响和降级路径已评估；
- 新依赖的维护、许可证、体积和退出路径已记录；
- 用户可见变化有可访问性和无动画路径；
- 必要的 migration、protocol compatibility、回滚和诊断信息可用；
- 改动形成聚焦、说明清楚且工作树干净的本地提交；远程写入仍按授权执行。
