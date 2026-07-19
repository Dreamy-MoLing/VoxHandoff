# Agent Talk 正式开发基线

> 基线版本：1.43<br>
> 生效日期：2026-07-19<br>
> 状态：Active

本目录是 Agent Talk 唯一有效的产品与工程基线。实现、评审、测试和发布只引用这里的文档：

1. [`PRODUCT.md`](PRODUCT.md)：产品目标、用户流程、平台范围、功能需求和验收口径；
2. [`ARCHITECTURE.md`](ARCHITECTURE.md)：进程、协议、数据、网络、语音、视觉和安全架构；
3. [`DELIVERY.md`](DELIVERY.md)：仓库结构、里程碑、质量门、PoC、发布与风险处置。

根目录 `docs/` 是前期分析输入，已经完成吸收和冲突消解。它不再是需求来源，不得在代码注释、Issue、测试或新文档中引用；如它与本目录冲突，以本目录为准。

## 决策优先级

当实现遇到未覆盖情况，按以下顺序决策：

1. 数据不丢失、审批不绕过、命令不重复执行；
2. 用户能看见真实状态、完整回复和实际执行主机；
3. 官方协议与官方 SDK；
4. 活跃、成熟、五端可用且许可证可接受的社区方案；
5. 小型、版本化、可替换的自研适配层；
6. 视觉一致性和性能优化。

任何更改非协商安全约束、公共协议、权威数据模型或平台范围的决定，都必须先修改本目录并记录理由、迁移方式和验收变化。

## 修订记录

| 版本 | 日期 | 说明 |
| --- | --- | --- |
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
