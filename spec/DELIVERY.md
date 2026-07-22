# VoxHandoff 开发与交付规范

## 1. 当前状态

基线日期环境：Fedora 44、Node.js 22.22.2、npm 10.9.7、Python 3.14.6、uv 0.11.26、Codex CLI 0.144.6、Hermes Agent 0.19.0、ffmpeg 8.1.2；项目内 Buf CLI 1.72.0、Protobuf-ES 2.12.1、node-postgres 8.22.0 和本地 Dart `protoc_plugin` 25.0.0。PostgreSQL 集成基线为 17 Alpine、manifest digest `sha256:af194ccf3e2d7fe367012c7b88ce8b816c5c889b18a5b316799a1f0d7eac746a`。M2 使用官方 stable Flutter 3.44.6 / Dart 3.12.2 用户级 SDK，Linux archive SHA-256 固定于 `toolchains/flutter.json`；Fedora 主机已安装 Clang 22.1.8、GTK 3 与 libsecret development headers，Linux release build 和 Secret Service 真读写/删除通过。当前主机仍无 Android SDK；PR #1 的固定版本 runner 已完成 Android/iOS/macOS/Windows build。

当前阶段：M2 Flutter 文字客户端与同步完成；PR #1 的首轮 GitHub Actions run `29899751800` 已通过 Node/PostgreSQL、Linux quality/Secret Service、Android、macOS/iOS 和 Windows 全部门。M-1、M0 与 M1 已完成。下一阶段从 M3 语音闭环开始，不得回退 M2 的完整文字、审批、lease、cursor 或 uncertain 语义。

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
- Codex 真 failure probe：无效模型产生连续的 `request.accepted` sequence 1、`request.failed` sequence 2，无自动重试，失败/中断/取消终态均不生成可误解为成功的 speech text；
- Hermes fake HTTP/SSE 契约测试、脱敏 fixture、事件大小上限、错误正文隔离、approval/stop idempotency 和 client recreation；
- Hermes 0.18.2 隔离真链路：独立 `/tmp` HERMES_HOME、loopback API、无消息平台凭据；同一 session 10/10 轮完成且 identity/sequence 连续，stop 得到 `request.cancelled`，manual approval 保持阻塞且只以 stop 结束，gateway 重启后 session 可继续；
- Hermes 非优雅断线：在 `tool.started` 后 SIGKILL 仅监听 18642 的隔离 PID，partial lifecycle 后追加连续 `connection.lost`，PoC 进入 `uncertain`、不生成 speech、不自动重提；
- `agent_talk.v1` Protobuf/Buf 公共 schema：版本握手、固定 capability/error/event taxonomy、Client/Node 双向流、配对和耐久命令消息；
- 从同一 schema 生成 TypeScript 与 Dart/gRPC binding；Buf lint/build、core 契约对齐、生成物一致性、breaking baseline 和握手协商测试进入质量门；
- PostgreSQL 初始 migration 与 acceptance ledger：设备/scope、lease、固定 Agent/Node/capability、request/event/sequence 和双 outbox 在同一事务内；
- Gateway 账本 fake 覆盖并发 duplicate、idempotency/identity conflict、权限/租约/目标失败和完整回滚；隔离 PostgreSQL 17 覆盖 migration 幂等/篡改拒绝、Gateway recreation、并发 duplicate、连续 sequence 与失败回滚；
- 30 秒 control lease 状态机：只允许带 `send|interrupt|approve` scope 的 active device 获取控制；续租递增 revision，其他设备必须带当前 lease/revision 显式 CAS 接管，过期不推导隐式接管，成功变化写无正文安全审计；
- `0002_approval_rejected_state.sql` 以只向前 migration 将初始数据库约束的 `denied` 修正为规格唯一名称 `rejected`，不改写已提交的 `0001`；
- Buf Connect-ES/Node gRPC 双向流入口：Client/Node 身份由认证上下文绑定，握手前只接受 heartbeat/明确协议错误，role/version/metadata/attachments 逐项验证，每帧复核撤销，Node registration 必须匹配 opaque principal；
- 真实随机 loopback HTTP/2 gRPC 测试已通过；无 TLS server 只允许显式测试模式绑定字面量 `127.0.0.1`/`::1`，非 loopback 或隐式明文监听在构造期拒绝；
- Client 流已接通 `send`、lease acquire/renew、`GetRequest`、有界 replay（1-500）和精确 Ack；acceptance proof 来自耐久请求，未知事件以 `UNSPECIFIED + unsupported` 保留关联，不映射为成功/失败，Ack 只有命中 eventId/conversation/sequence 才单调推进 device cursor；
- `0003_request_failure_details.sql` 只向前增加 stage/category/code/safe message/retryable 完整失败事实；GetRequest 不再猜测失败分类。真实 PostgreSQL 已覆盖 status、顺序 replay、合法/非法 Ack 和 cursor upsert；
- Node registration 将 Agent capability 和当前认证连接写入权威账本；dispatch outbox 只向固定 node/agent/capability 投递，同连接 heartbeat 不重复发送，换连接以相同 dispatch/request/idempotency identity 安全重投；
- `0004_dispatch_ack_facts.sql` 保存 dispatch Ack/失败和 Node 源 sequence；旧连接 Ack/event、乱序或重复 source sequence、eventId 换 payload、终态后事件均拒绝。拒收 dispatch 同事务写完整 `request.failed`、Gateway sequence 与 event outbox；
- `0005_interaction_commands.sql` 建立 control command、clarification 和 approval resolution 事实约束；interrupt 只有当前 lease、`interrupt` scope、非终态 request 和固定 capability 允许，同事务写 `request.interrupting`、dispatch/event outbox，同 idempotency 精确重试不重投；
- Node stream 将 interrupt outbox 映射为 `DispatchInterrupt`；换连接仍使用原 command/request/idempotency identity，Ack 单独推进 control command，不把停止 TTS 或本地取消混成 Agent interrupt；
- Node `approval.required` 在事件同事务创建绑定 request/node/agent、摘要 hash 和 expiry 的 pending approval；expired/cancelled/resolved 只允许与耐久状态机一致，request 终态只取消仍 pending 的交互，不改写既有用户决定；
- Client approval 决策必须同时通过 active device、`approve` scope、当前 lease、非终态 request、pending/未过期状态和原摘要 hash；CAS 同事务写 approved/rejected、device/idempotency/command、无正文安全审计与固定 Node outbox，精确重试返回原决定，其他并发或迟到决定不投递；
- Clarification required/expired/cancelled/resolved 与 Node event 同事务维护；Client 只接受用户确认的非空文字，要求当前 lease、`send` scope、clarification capability、pending/未过期状态和 Agent 字节上限，明确不借用 `approve` scope；
- Clarification CAS 同事务保存 confirmed text 到权威交互表并创建固定 Node outbox；安全审计只含 opaque target hash，不含正文。重连使用原 command/request/clarification/idempotency identity，精确重试不重复提交；
- PostgreSQL event outbox pump 以 worker identity、`SKIP LOCKED` 和精确 outbox/event CAS 发布已提交事件；交给 live hub 后标记 delivered，发布失败回到有界重试，Gateway 重建仍从 pending/in-flight 事实恢复；
- 认证 Client 握手后才可接收 live event，每个出站事件前复核撤销；仅 observe/控制 scope 订阅。有界慢消费者溢出时明确断流并要求从耐久 cursor replay，live 内存队列不是权威副本；
- 配对 schema 已扩展为 `Begin → Inspect/Approve → Complete → Confirm`，固定 requested/approved scope、Gateway/设备 fingerprint 与 audience 核对、Ed25519 proof-of-possession、确认后签发和 refresh rotation；旧 draft proof/token 字段只保留 wire 兼容且不得签发有效凭据；`ResolveApproval`、远程配对授权与撤销携带设备签名，TS/Dart binding、contract 和 breaking gate 已通过；
- TypeScript 与 Dart 的签名 framing helper 均使用 domain separation、固定字段顺序与大端长度前缀，并规范化 scope、构造 pairing/confirmation/admin/refresh/revoke/approval/owner payload；跨语言固定 byte fixture 已证明 canonical framing 与 pairing proof 完全一致。Gateway 只接受规范 Ed25519 SPKI DER，以 Node CSPRNG 生成 opaque secret/challenge，精确校验 64-byte 签名，并将明文 HTTP audience 限于显式 loopback 测试；
- Gateway 配对领域状态机已实现 Begin/Inspect/Approve/Complete/Confirm：Begin 受持久化接口限速，owner 只能缩减请求 scope 且必须签署 fingerprint/audience/nonce，设备先证明新私钥、再签署独立 confirmation payload；确认事务前不产生 bearer token，账本只接收 token hash。离线事务 fake 已覆盖 owner 门、双签名、过期事实提交、nonce 重放、scope 越权、并发精确重试和审计无 secret；
- Confirm 对相同 pairing/credential/signature 的并发调用只执行一次激活事务，并在最多两分钟的进程内恢复窗口返回完全相同的 token 响应；缓存键只含 identity/signature hash，返回前重新锁定并核对 active credential generation、token hash、scope 与有效期，refresh/revoke/过期后立即失效。不同签名、窗口外请求或 Gateway 重启仍明确冲突并由 Client 保持 `uncertain`，不会重新激活或签发第二组 token；
- `0006_device_pairing.sql` 只向前增加 pairing、pending/active credential、owner-bootstrap origin、签名 nonce 和持久限速窗口；pending credential 不进入 active device 权威表，Confirm 才同事务创建设备并保存 bearer hash。固定 PostgreSQL 17 已验证完整双签名配对、Gateway/ledger 重建后确认、migration 幂等/篡改门及数据库中无明文 token；
- `0007_credential_rotation.sql` 保存已消费 refresh hash/generation；refresh 必须由绑定设备对 token hash、generation、audience 和单次 nonce 签名，成功事务废止旧 access/refresh 并递增 generation。只有旧 token 的有效设备签名重放才撤销整个设备凭据族，错误签名不能借机 DoS；远程撤销要求 `administer` active credential、目标/原因/audience/nonce 签名。离线与固定 PostgreSQL 17 均覆盖轮换、历史、hash-only、撤销和审计；
- PairingService 已接通全部七个 RPC；Inspect/Approve/Revoke 从当前 bearer 绑定管理员 device/credential，rate-limit identity 由受信 server callback 提供而不信任客户端转发头。PostgreSQL access authority 只接受 active device+credential、匹配 audience/scope、未过期且当前 generation/token hash；Client 每帧与 live 出站复核 generation，refresh 立即关闭旧流，revoke 关闭全部流。真实 HTTP/2 TLS 测试确认未信任自签名证书失败、显式 CA 信任后 Begin 成功；
- Client Approval 执行层强制 Ed25519 设备签名，payload 绑定 credential/device、实际 Node host、Gateway audience、request/approval、原 operation hash、approve/deny 和单次 nonce；credential active/scope/key binding、签名、nonce 消费与 approval CAS 同一事务。签名与 nonce 进入 control-command payload hash，精确重试验证原签名后返回既有决定；缺失、篡改、跨 host/audience 或重放不能产生 Node dispatch；
- 初始 owner 只通过 Gateway 进程内本机/部署私有入口创建，不增加未认证网络 RPC；调用方必须提交绑定规范 Gateway audience、完整 owner scope、公钥 fingerprint 和 nonce 的 Ed25519 持钥证明。恢复使用独立签名 domain，不能复用初始引导证明；PostgreSQL advisory transaction lock 在同一事务撤销旧 owner 设备及 credential family、清空 bearer hash、激活新 owner 并写两条无正文审计。真实 PostgreSQL 已覆盖重复引导拒绝、旧流 revalidation 失败、新 owner 认证与 Gateway 重建后的完整凭据链路；
- fake Client 与 fake Node 已经同一 Gateway 双向流和真实 PostgreSQL 完成组合退出验收：首次 acceptance 响应丢失后重建 Gateway，精确 Client 重试仍只保留一个 request；Node 连续换连接收到同一 dispatch identity，旧 source sequence 以稳定错误拒绝，精确事件重试不增写；最终 request、dispatch、四条连续 Gateway event 与 Client cursor 收敛；
- 官方 Flutter 3.44.6 / Dart 3.12.2 SDK archive 已固定版本与 SHA-256，生成 Windows/Linux/macOS/iOS/Android 共用客户端工程；Dart protocol package 和客户端均进入 `npm run flutter:check` 的真实 analyze/test 门；
- Flutter shell 已建立 Riverpod application/domain 分层、原创“夜航信号台”token/静态信号镜和未配对本地草稿体验；发送默认禁用，草稿须显式确认，request acceptance 必须匹配预生成 identity，`uncertain` 禁止覆盖或静默重提；桌面/390px 手机 golden、响应式 widget 和文字对比度/标签/触控目标 accessibility test 已进入质量门；
- Riverpod `DevicePairingController` 已通过可替换 workflow factory 组合 OS 安全存储、TLS channel、生成的 Pairing client 和 application coordinator；恢复、完成、显式重试、放弃和 channel 关闭均不泄漏到 Widget，基础设施创建失败只发布固定安全文案。用户入口采用原创硬边“手动链路”面板，展示 Establish/Verify/Prove/Sealed 阶段、完整 code/fingerprint/audience/scope 事实、可选私有 CA PEM 与不确定 Confirm 的远端凭据确认；任何 owner approval 仍须在独立已授权设备完成。完整阶段、390px 无溢出、触控语义及桌面/手机 golden 已进入门禁；
- Dart 客户端在签署配对 proof/confirmation 前必须严格解析 Gateway 待签 bytes，并以本地已检查的 audience、fingerprint、scope 与 credential facts 逐字节重建比对；`DeviceKeyVault` 已隔离待配对 Ed25519 seed、规范 SPKI/fingerprint 与签名能力，RFC 8032 向量、重启读回、损坏拒绝和显式丢弃均有离线测试；
- 客户端配对 application coordinator 已固定 `Begin → owner approval → Complete → Confirm → credential commit` 状态机：challenge/signature/token 不进入公开 UI state，Complete 兼容 token 非空即拒绝，Confirm 成功和 credential vault 落盘前不显示 paired；网络结果不明不自动重试，只有用户显式恢复才复用同一签名，恢复冲突继续保持 `uncertain`。待配对密钥仅在凭据保存后幂等提升为 active，离线测试覆盖双签名、未批准、篡改事实、提前 token、落盘失败、重启恢复与远端可能已激活时的删除确认；
- `FlutterSecureValueStore` 已把 key、checkpoint、Gateway trust profile 与 access/refresh credential 接到五平台 OS-backed 安全存储；Android 使用独立 namespace、关闭损坏自动清空与应用备份，iOS/macOS 声明 Keychain Sharing，credential 存储键只含 credential ID 的 SHA-256。严格版本化 codec 对 malformed bytes、未知 enum、重复 scope、identity 冲突 fail closed；active credential 在 pairing checkpoint 删除后仍可恢复 paired 状态，显式 CA 也随 profile 恢复。Fedora release 二进制已对 Secret Service 完成固定非敏感值的写入、读回、删除和删除后空读，输出不含 secret；
- 客户端配对已通过生成的 Dart `PairingServiceClient` 接入 Begin/Complete/Confirm unary RPC，每次调用固定有限 timeout 且只尝试一次；Complete 明确清空废弃 proof 字段并提交 Ed25519 结构化签名。Gateway 以 trailer 返回受控领域错误码，客户端仅接受本地白名单并使用固定安全文案，远端 message 不进入 UI；断线、超时、取消及未知本地异常统一保持 `uncertain`，离线 fake 覆盖三阶段 wire 映射、未批准、未知错误码和无自动重试；
- `GatewayGrpcChannelFactory` 只从无 userinfo/path/query/fragment 的规范 HTTPS audience 建立 channel，固定有限 connect timeout，使用系统信任或启动前可解析的显式 CA；生产 API 不暴露 bad-certificate callback。明文只存在于命名为 `insecureLoopbackForTests` 的 factory，且仅接受字面量 `127.0.0.1`/`::1`，离线测试覆盖自签 CA、地址混淆、非 loopback 明文和超界 timeout；
- Dart 客户端已复用生成的 `GatewayControlServiceClient` 和 `grpc` SDK 建立认证双向流：active bearer 仅进入 metadata，Client offer 为首帧，连接 timeout 与 handshake timeout 有界且不误作长连接总 deadline；Gateway role、协议 1.0、connection ID、capability、scope 与 attachments=false 均 fail closed。业务帧先于握手、重复握手、空帧、远端 protocol error、同步/异步 transport 故障均脱敏且不自动重连；离线 fake 覆盖命令、精确 Ack、heartbeat、event 映射、超时、过期凭据与 secret diagnostics。`toolchains/protocol.json` 固定有序 proto SHA-256，repository gate 防止 Dart offer 与 schema 静默漂移；
- Client event domain 已与 protobuf/Flutter 隔离，完整保留 request-bound connection lifecycle、message、tool、approval、clarification、terminal failure 和 unsupported 安全载荷；Gateway mapper 严格校验协议、type/payload、identity、uint64、UTC timestamp、审批 hash 与 1 MiB 上限，并只公开固定脱敏异常。`ClientEventConvergence` 按 request 的 origin device/conversation/session route 收敛所有已认证观察设备，要求 sequence 连续，以完整 typed payload 与 envelope SHA-256 识别精确重复/冲突；中央 frame router 作为 live frame 唯一消费者，在耐久提交或精确读回后才 Ack，缺口不展示/不 Ack且同一未完成页只发送一个有界 replay，异常关闭流但不重提用户命令；
- Drift 2.34.2 + SQLite 3.5.0 已实现私有生成数据库与安全领域 facade：完整事件、request route、accepted sequence 和 conversation cursor 原子提交，uint64 以 20 位十进制 TEXT 保存，cursor 通过复合外键指向精确事件。本地 command/idempotency/hash 与跨设备 route 分表，`prepared → outcomeUnknown → accepted/rejected` 只允许前向 CAS；confirmed text 不进入提交状态表，request acceptance 可在同一事务收敛未知结果。内存并发/回滚、typed payload 损坏、SQLite CHECK/FK、完整文件关闭重开与 Flutter 全量测试均已通过；
- 公共协议以追加字段扩充 `RequestStatus` 的 origin device/session route，并增加关联 command/conversation/sequence/count 的 `ReplayCompleted` 尾帧；Gateway 每个 replay 页按序返回事件后给出耐久批次边界。Flutter frame mapper 将 protobuf 隔离为领域 frame；中央 router 启动时从 Drift 枚举已跟踪 conversation（无 cursor 从 0 开始），按耐久 cursor 分页，未知 request 事件有界缓冲且每个 request 只查询一次状态，严格保存 route 后才重放原事件和精确 Ack。恢复路径只产生 `GetRequest`/replay/Ack，不生成 `Send` 或其他可执行命令；
- 公共协议追加 `ListDirectory`、`CreateConversation`、`GatewayDirectory` 与 `ConversationDescriptor`；`0008_conversation_directory.sql` 以 nullable expand-first 字段兼容旧会话，并把新会话绑定创建 device/command/idempotency、Node/Agent/capability/session/title。Gateway 对目录按认证 observe/control scope读取，对创建按 send scope、当前非 revoked Agent 与 capability revision 校验；并发相同创建只返回同一事实，identity 或 idempotency 冲突 fail closed；
- Flutter production workspace 从 OS 安全存储加载 active credential 与 Gateway trust profile，建立 TLS gRPC、Drift 与唯一中央 router；目录、会话、完整 message/tool/terminal、lease、审批和澄清都只从已映射领域状态进入 UI。发送前原子保存 route、command/idempotency 与 confirmed-text SHA-256，正文不进入提交状态表；只有本设备持有未过期 lease 且草稿已显式确认才写出一次 `Send`，并且在 wire write 前进入 submitting。已 prepare 的写出失败或断流都前向推进为 `outcomeUnknown`，只允许 status/replay 恢复；本设备精确 lease 至多每 10 秒单次续租，接管、断流和过期取消旧 timer，未收到新 revision 不用旧 revision 重试；
- 审批按钮永不自动触发；用户明确 approve/deny 后，Client 从耐久 request route 取实际 Node host，使用 active credential key 对 credential/device/host/audience/request/approval/decision/original hash/nonce 签名，再携当前 lease 发出一次。澄清必须在独立对话框编辑并明确确认；interrupt 与其他设备接管也必须点击显式动作；
- 两份独立 Drift 账本与中央 router 的组合验收覆盖桌面/手机共同观察同一完整事件、手机无隐式控制、带当前 revision 的显式接管、断线后从 sequence 2 启动 replay 并收敛到 4；两端无额外 `Send`。已连接工作区另有桌面/390px 手机 golden、完整回复与显式审批 widget gate；
- CI 新增固定 Flutter 3.44.6 的 Linux analyze/test/release/Secret Service 门，以及 Android debug APK、macOS release、iOS simulator 和 Windows release 构建矩阵；根 `npm run check` 已按 workspace 依赖拓扑在 protocol `--noEmit` 校验后显式生成 `dist`，以移除 `origin/main` 干净 runner 在 Gateway 检查时找不到 `@agent-talk/protocol` 的顺序缺陷；Dart 生成一致性门则在固定 Flutter SDK 就绪后运行。这些是共享 M2 客户端的合并门，不替代 M5 的签名、安装、升级、卸载与实体设备发行验收；
- Dart protocol 依赖经真实 pub solver 将 `protobuf` 修正为与 `grpc 5.1.0` 相容的 6.x，不使用 dependency override；客户端运行依赖已固定 `drift 2.34.2`、`path_provider 2.1.6` 和传递依赖 `sqlite3 3.5.0`，开发生成器固定 `drift_dev 2.34.0` / `build_runner 2.15.1`。PowerSync 未进入依赖，仅保留通过独立许可、运维、最小授权和量化收益 gate 后的可选 adapter；
- 仓库级威胁模型：关键资产、攻击者、九条信任边界、重点攻击故事和严重度校准；
- repository consistency check 和最小权限 GitHub CI：locked install、check、offline tests。

M2 之后未完成或未实测：

- OpenClaw adapter；
- STT、GPT-SoVITS 和音频播放真链路；
- 实体手机/桌面的远程网络、非 Linux keyring 真读写、签名打包、安装/升级/卸载与发布测试；这些仍是 M5 发行门，不得从 CI 编译结果推断通过。

Hermes 默认 gateway 当前由 user systemd service 运行并关联 QQBot；它不是 VoxHandoff 测试资源。Live PoC 必须使用不同 HERMES_HOME、端口、PID/state 目录和只含所需 provider key 的干净子进程环境，不得停止、重启或复用默认 gateway。

## 2. 仓库布局

```text
apps/
  poc-cli/              # 可重复协议/故障 PoC
  client/               # Flutter 五端共享 shell、领域/application 层与平台 runner
packages/
  core/                 # 无外部依赖的领域模型和状态机
  adapters/             # Agent 原生协议适配器
  protocol/             # Protobuf/Buf schema、TS/Dart binding 与协商测试
  sidecar/              # desktop stdio host（待建）
services/
  gateway/              # 耐久控制面、gRPC/HTTPS、配对、凭据与 PostgreSQL adapter
  node/                 # Agent 主机 Connector（待建）
  stt/                  # Python STT sidecar（待建）
infra/
  postgres/             # forward-only migrations；backup/restore tests 待建
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
- 规格未覆盖的普通实现问题可先以隔离 spike 和真实构建/测试决定；形成提交时必须同步写明稳定选择、拒绝方案、迁移/回滚和验收影响。涉及非协商安全、公共协议、权威数据或平台范围时仍须先更新规格。

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
- Drift schema 变更做旧版本 Client 兼容、文件重启和离线升级测试；
- 若通过 gate 引入 PowerSync，其 sync rules 必须进入版本控制并做最小授权、升级和 cursor-sync 退出测试。

### 3.6 Git 与版本治理

- `main` 保持可构建、可测试；不在 `main` 上强制改写已提交历史，修正使用新提交或 `revert`；
- 提交采用 `feat:`、`fix:`、`spec:`、`test:`、`refactor:`、`build:`、`chore:` 等清晰前缀，冒号后的主题和正文默认使用中文；一个提交只包含一个可解释、可回退的逻辑变化；
- 提交前至少运行与改动相关的 check/test，规格或脚本变化额外运行 repository consistency check；失败证据不得通过跳过测试隐藏；
- 自动化 Agent 可以在验证后创建聚焦的本地提交，但 push、PR、tag、发布和远程部署仍需明确授权；
- 产品发行使用 SemVer 和 annotated tag `vX.Y.Z`；首个公开稳定协议前保持 `0.y.z`，但任何已发布 wire/data breaking change 仍须提升 protocol major 并提供迁移说明；
- protocol major/minor、数据库 migration 序号和产品版本分别管理，不从显示版本推导兼容性；
- 每个发布 tag 对应变更记录、依赖/许可证快照、SBOM、migration/rollback 说明和已通过的发布门；
- 不提交 secret、`.env`、原始 live payload、原始录音、临时生成的 Codex binding 或设备专属产物。

### 3.7 关键依赖记录

| 依赖 | 固定基线 | 许可证 | 维护/覆盖证据 | 退出路径 |
| --- | --- | --- | --- | --- |
| `@bufbuild/buf` | 1.72.0，npm lockfile | Apache-2.0 | Buf 官方 CLI；本地和 CI 使用同一项目内二进制 | 保留标准 `.proto`，可退回 `protoc` + 独立 lint/breaking 工具 |
| `@bufbuild/protoc-gen-es` / `@bufbuild/protobuf` | 2.12.1，npm lockfile | Apache-2.0；runtime 另含 BSD-3-Clause | Buf 官方 Protobuf-ES，Node 22 strict 编译已通过 | wire schema 不变时替换 TS generator/runtime，并以 fixture 验证 |
| `protoc_plugin` Dart remote plugin | 25.0.0，`buf.gen.dart.yaml` | BSD-3-Clause | Dart 官方维护的 generator；已生成 Dart 3.3+ 与 gRPC binding | 安装同版本本地 plugin，或在保持 wire schema 下替换生成器 |
| Dart `protobuf` / `grpc` / `fixnum` | `^6.0.0` / `^5.1.0` / `^1.1.1` | BSD-3-Clause / Apache-2.0 / BSD-3-Clause | dart.dev/google.dev 发布，覆盖 Flutter 五端；Flutter 3.44.6 的真实 pub solver 已验证 grpc 5.1.0 要求 protobuf 6.x | 生成层隔离在 `agent_talk_protocol`，替换 transport 不改变 Core/UI 契约 |
| `flutter_riverpod` | 3.3.2，Flutter lockfile | MIT | pub.dev 五平台声明；只承载可重建 application/view state，真实 analyze/widget test 已通过 | provider 后方保留普通 Dart domain/controller；可替换状态管理而不改变 Gateway 耐久事实 |
| Dart `cryptography` | 2.9.0，Flutter lockfile | Apache-2.0 | Ed25519/SHA-256 覆盖 Android/iOS/Linux/macOS/Windows；短配对签名使用统一 API 和纯 Dart fallback | `DeviceKeyVault` 隔离算法/密钥实现；可切 OS-backed signer 而不改变 pairing/application 契约 |
| `flutter_secure_storage` | 10.3.1，Flutter lockfile | BSD-3-Clause | 发布者验证、五平台 federated plugin；Android RSA-OAEP/AES-GCM、Apple Keychain、Linux libsecret、Windows 平台实现；完整 Dart analyze/test 已通过 | 所有调用隔离在 `SecureValueStore`，可逐平台替换原生 signer/store；普通数据库只保留 opaque 引用 |
| `drift` / `path_provider` / `sqlite3` | 2.34.2 / 2.1.6 / 3.5.0，Flutter lockfile | MIT / BSD-3-Clause / MIT | Drift Native background executor + Application Support 固定路径覆盖五个目标平台；内存事务、SQLite 约束与真实文件重启测试已通过；未保留无实际调用的 `drift_flutter` | `ClientEventLedger`/storage adapter 隔离 schema、路径与 executor；可替换 SQLite driver 或历史同步 transport，不改变完整事件、cursor、replay/Ack 契约 |
| `drift_dev` / `build_runner` | 2.34.0 / 2.15.1，Flutter lockfile | MIT / BSD-3-Clause | 仅开发期生成；真实 pub solver 证明 `drift_dev >=2.34.1+1` 的 Analyzer 13 与 Flutter 3.44.6 固定测试栈冲突，因此精确固定最后兼容版本而不使用 override | 提交生成的 Dart 文件并做一致性门；升级 Flutter 后单独重跑 solver/generator，也可改为 `.drift`/手写 SQL adapter 而不改变领域接口 |
| `pg` / `@types/pg` | 8.22.0 / 8.20.0，npm lockfile | MIT | node-postgres 长期维护；使用底层 Pool/transaction API，不引入 ORM | `GatewayLedger` 隔离 SQL；可替换其他 PostgreSQL driver 而不改变 acceptance 语义 |
| PostgreSQL test image | 17 Alpine，固定 manifest digest | PostgreSQL License；镜像含各组件许可证 | 官方镜像；本地隔离测试和 CI 使用同一 digest | 生产部署独立；测试可换受支持 PostgreSQL 版本并先跑 migration/fixture gate |
| `@connectrpc/connect` / `@connectrpc/connect-node` | 2.1.2，npm lockfile | Apache-2.0 | Buf/CNCF Connect 官方 TypeScript 实现；支持 Node、gRPC 与 streaming，真实 HTTP/2 测试通过 | service 只依赖生成的标准 Protobuf descriptor；可换 `grpc-js` 而不改变 wire schema/账本 |

TypeScript 与 Dart binding 都使用仓库固定的本地 Buf plugin；依赖已锁定后不把私有 proto 上传到远程 generator。普通 `npm run check` 校验已提交 TypeScript 生成物并先 emit protocol `dist` 再检查消费者；CI 与显式 `protocol:check:dart` 使用固定 Flutter SDK 内嵌 Dart 重新生成并逐字比较。`npm run flutter:check` 已真编译 protocol package 并分析、测试共享客户端；在各目标平台 toolchain 和 runner build 实际通过前，仍不得把它表述为“五端编译成功”。

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

### M0 — 协议核心（完成：2026-07-18）

目标：把已有 PoC 提升为可依赖的 Agent 领域层。

- 完成 Codex interrupt、approval 和错误真链路；
- 在隔离 Hermes profile 完成 10 轮、stop、approval、断线和重启；
- 固定统一 capability/error/event taxonomy；
- 扩展状态机 property/failure tests；
- 保存脱敏协议 fixture 和阶段指标；
- `check`、`test`、`protocol:codex` 全绿。

退出条件：Codex/Hermes 不靠 UI 抓取完成可靠多轮；断线不重复提交；审批不丢失。

完成证据：Codex completion/resume/interrupt/approval/failure 真链路；Hermes 隔离 10 轮、stop、approval、gateway restart/session resume、SIGKILL/uncertain 真链路；统一 taxonomy、failure/property tests、脱敏 fixture、协议兼容检查和完整本地质量门均通过。

### M1 — 公共协议与 Gateway（完成：2026-07-18）

目标：建立五端和远程 Node 都能依赖的耐久控制面。

- 创建 Protobuf/Buf schema，生成 TypeScript/Dart；
- 实现 gRPC Client/Node 双向流和 HTTPS 配对；
- PostgreSQL migrations、transactional outbox 和 sequence；
- 设备 identity/scope/control lease；
- live replay、gap、idempotency、uncertain 和吊销测试；
- 本地 embedded 模式可不开放固定端口。

退出条件：fake Client + fake Node 能在重连、重复、乱序、Gateway 重启后收敛。

完成证据：同一组合测试经实际 `ConnectClient`/`ConnectNode` 双向流和固定 PostgreSQL 17 执行；首次响应丢失、Gateway 实例重建、Client 精确重试、Node dispatch 重投、旧序拒绝、事件精确重试、终态 replay 与 cursor Ack 后，数据库只有一个 request/dispatch，request=`completed`、dispatch=`delivered`、Gateway sequence 和 cursor 均为 4。协议、离线测试、真实 HTTP/2 TLS 与 PostgreSQL 门同时通过。

### M2 — Flutter 文字客户端与同步（完成：2026-07-22）

目标：先完成五端共享的文字 Agent 产品骨架。

- Flutter shell、Riverpod application layer 和 Fairy 静态信号镜核心；
- 原创“夜航信号台”token、组件状态目录、手机/桌面 golden 与 accessibility gate；
- 登录/配对、Agent/会话选择、完整回复、工具事件和审批；
- gRPC live stream；
- Drift 原子本地账本与已认证 cursor-sync；PowerSync 只做独立许可证/运维/收益 gate；
- 一台桌面和一台手机观察、接管、断网和恢复；
- OS secure storage 五端真实测试。

退出条件：一桌面一手机对同一会话无重复、无串线，离线历史可读；cursor-sync 是必须通过的基线，PowerSync gate 失败不阻塞 UI。

完成证据：Gateway directory/conversation 的追加协议、expand-first PostgreSQL migration、并发幂等创建和生产 Flutter workspace 已接通；两个独立 Client 账本/router 对共同事件、显式接管、断线与 cursor 续播收敛且没有生成 Send；完整回复、工具/审批/澄清/终态、签名审批、lease 定时续租和 uncertain 不重提均有离线门。固定 PostgreSQL 17 的 migration/并发/恢复门与真实 HTTP/2 TLS loopback 已在 Fedora 44 复验；Linux release 与 Secret Service 写/读/删真链路通过。[GitHub Actions run 29899751800](https://github.com/Dreamy-MoLing/VoxHandoff/actions/runs/29899751800) 进一步通过 Node/PostgreSQL、Linux quality/keyring、Android、macOS/iOS 与 Windows 全部门；实体设备与签名发行仍按 M5 单独验收。

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
- PostgreSQL/Drift/Gateway 重启和升级；启用 PowerSync 后再加入其退出/恢复矩阵；
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
npm run protocol:generate
npm run protocol:breaking
npm run protocol:check:dart
AGENT_TALK_POSTGRES_URL=<isolated-loopback-url> npm run test:postgres
AGENT_TALK_LOOPBACK_INTEGRATION=1 npm run test:transport
npm run protocol:codex
npm run flutter:check
VOXHANDOFF_SECURE_STORAGE_SELF_TEST=1 \
  ./apps/client/build/linux/x64/release/bundle/agent_talk_client
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
npm run poc -- codex \
  --prompt "Reply with exactly: this should not complete" \
  --failure-probe
npm run poc -- hermes \
  --base-url http://127.0.0.1:18642 \
  --token-env HERMES_API_KEY \
  --prompt "Reply with exactly: ready"
npm run poc -- hermes \
  --base-url http://127.0.0.1:18642 \
  --token-env HERMES_API_KEY \
  --prompt "Reply with exactly: ready" \
  --create-session --rounds 10
npm run poc -- hermes \
  --base-url http://127.0.0.1:18642 \
  --token-env HERMES_API_KEY \
  --prompt "Write a long numbered list. Do not use tools." \
  --stop-after-ms 500
npm run poc -- hermes \
  --base-url http://127.0.0.1:18642 \
  --token-env HERMES_API_KEY \
  --prompt "Use the terminal tool to run bash -lc 'exit 0'. Do not do anything else." \
  --approval-probe
npm run poc -- hermes \
  --base-url http://127.0.0.1:18642 \
  --token-env HERMES_API_KEY \
  --prompt "Use the terminal tool to run sleep 30, then reply: finished." \
  --disconnect-probe
```

`--disconnect-probe` 只在隔离 gateway 中使用：先从独占 loopback 端口精确解析临时 PID，观察到 `tool.started` 后终止该 PID。禁止用进程名、宽泛 PID 匹配或默认 gateway 做故障注入。

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
| PowerSync 引入第二同步/授权平面 | 当前采用 Drift + 已认证 cursor sync；PowerSync 仅位于可选 Sync Adapter | 只有许可、运维、最小授权和量化收益同时过门才引入 |
| 五端插件能力不一致 | record/media/security adapter + real device tests | 单平台失败显式降级或写原生 plugin |
| TTS 冷启动/崩溃 | 常驻预热、分段、纯文字降级 | 不达标时限制自动播报长度 |
| STT 技术词误识别 | 默认确认、高风险审批独立 | 30 条基准不达标切换后端 |
| 多设备重复提交 | DB uniqueness、idempotency、lease、uncertain | 任何重复执行为发布阻断 |
| 视觉模板化或近似第三方资产 | 原创视觉主命题、语义 token、组件状态目录、golden 和许可证记录 | 出现禁止的泛 AI 模板或无来源资产即退回设计门 |
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
