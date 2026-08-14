# VoxHandoff 决策记录

本文件保存当前开发路线中的产品取舍、技术选型、参考项目和未决门槛。
它不是新的需求来源：稳定的用户行为以 [`PRODUCT.md`](PRODUCT.md) 为准，
边界与协议以 [`ARCHITECTURE.md`](ARCHITECTURE.md) 为准，实际证据以
[`DELIVERY.md`](DELIVERY.md) 为准。本文件用于防止会话结束后丢失决策理由。

规则：改变产品范围、平台顺序、Agent 后端、信任边界、公共协议或权威数据
模型时，先追加一条决策并同步相关规格；实现和验证完成后，再把证据写入
`DELIVERY.md`。未经明确验证的内容只能写成“计划”或“未关闭”。

## D-001：重新开启开发，但只做 Android-first MVP

- 日期：2026-08-13
- 状态：Accepted
- 决策：从历史 Archived / Limited Maintenance 状态重新进入开发，当前只
  推进 Android 手机端 MVP。
- 原因：现有 Flutter、配对、Gateway、Direct LLM、录音和状态/安全测试基础
  已存在；当前最大产品缺口是手机端真实闭环，不需要重新建设 Agent 框架。
- 当前范围：Android 前台启动、配对、安全存储、Gateway/Hermes 文本会话、
  Direct LLM 纯聊天、按钮式录音、可编辑 STT 终稿、明确确认、流式回复和
  可选 TTS。
- 明确延后：iOS、桌面新功能、后台监听、唤醒词、全双工实时语音、本地手机
  Agent/STT sidecar、MCP/RAG/附件、新 Agent 后端、多用户和自动调度。

## D-002：保持现有后端边界，不复制 Hermes

- 日期：2026-08-13
- 状态：Accepted
- 决策：Hermes 是唯一具有 Agent/work 语义的后端；手机通过认证远程
  Gateway 访问 Hermes。Direct LLM 只走用户配置的 HTTPS API，不能拥有
  工具、审批、lease、执行主机或 Hermes 状态。
- 链路：Android Flutter → TLS/Tailscale/WireGuard → Gateway → PostgreSQL
  ledger → Node → Hermes。
- 取舍：继续使用现有 Protobuf/gRPC、Gateway/PostgreSQL、Node Connector、
  Riverpod、Drift 和安全存储，不引入新的 Agent 框架或实时媒体服务。
- 安全边界：手机不启动 Node、Hermes、Gateway、PostgreSQL 或本地 STT
  sidecar；Hermes 不直接暴露到公网。

## D-003：按一条纵向链路顺序推进

- 日期：2026-08-13
- 状态：Accepted
- 顺序：工具链可用性 → Android shell/配对 → 文本闭环 → 前台语音输入 →
  TTS/降级 → 实体 Android 验收。
- 规则：前一阶段的验收门没有关闭时，不并行开启后一阶段，也不同时推进
  iOS 或桌面功能。
- 停止条件：真实设备、真实服务或凭据缺失时停止在对应门前，保留
  `blocked`/`unverified` 证据，不用模拟测试替代实机结论。

## D-004：语音采用 text-first、前台、可确认流程

- 日期：2026-08-13
- 状态：Accepted
- 决策：录音 → 远程 STT → 可编辑文本 → 用户明确确认 → 发送 → 流式回复 →
  可选 TTS。手机不使用本地 STT sidecar，不默认上传原始录音，不自动确认
  或自动发送。
- 降级：STT、TTS 或播放失败时保留完整文字；不确定的远程接受结果不静默
  重试；用户开口默认只停止播报，不隐式中断 Hermes 工作。
- 尚未关闭：远程 STT/TTS provider、TLS、留存、同意文本、实体麦克风和
  中文语音质量需要真实设备与实际服务验收。

## D-005：参考项目只复用模式，不复制产品范围

GitHub 参考项目截至 2026-08-13 的用途如下。活跃度、issue 数和默认分支会
变化；许可证和 README 不能替代源代码审计或正式安全扫描。

| 项目 | 可复用方案 | 明确避开 | 许可证/安全备注 |
| --- | --- | --- | --- |
| [Hermes Agent](https://github.com/NousResearch/hermes-agent) | 保持后端能力兼容；沿用其 Agent、技能、Provider 和跨渠道事实边界 | 不重写 Hermes 的 Agent、Gateway 或实时语音能力 | MIT；上游很活跃，但上游活跃不等于本项目 H1 已验收 |
| [Open WebUI](https://github.com/open-webui/open-webui) | 响应式/PWA 手机交互、Provider registry、语音入口和可见的能力选择 | RAG、MCP、插件、多人权限、自动化和庞大服务端功能面 | 多阶段混合许可证并含品牌限制；只能借鉴交互/适配模式，不能直接移植代码 |
| [LibreChat](https://github.com/danny-avila/LibreChat) | Provider adapter、OpenAI-compatible 配置、流式响应恢复 | Agents、MCP、代码执行、文件、多人协作和 Web-only 产品范围 | MIT；有安全/隔离设计线索，但不能据此下无漏洞结论 |
| [Home Assistant](https://github.com/home-assistant/core) | 本地优先、事件驱动、设备能力、权限和离线降级边界 | 家庭自动化实体模型和大规模集成目录 | 成熟且活跃；参考其边界思想，不直接复用其平台架构 |
| [Jan](https://github.com/janhq/jan) | 本地配置/Profile、Provider 切换、窄原生边界 | 桌面中心的本地模型管理和 Tauri shell | Apache-2.0；可借鉴配置隔离，不替代手机 Gateway 架构 |
| [Pipecat](https://github.com/pipecat-ai/pipecat) / [LiveKit Agents](https://github.com/livekit/agents) | 未来全双工语音需要时参考 pipeline、取消、媒体传输和测试边界 | 当前 MVP 不引入 WebRTC、Python realtime server 或大 Provider 矩阵 | BSD-2-Clause / Apache-2.0；安全报告和许可证可查，但当前范围不需要引入 |
| [OpenVoiceOS](https://github.com/OpenVoiceOS/ovos-core) | Skill/Plugin 和语音 pipeline 的模块化思路 | message bus、复杂配置、遗留兼容和大依赖面 | Apache-2.0；其自身 audit 已记录依赖膨胀和配置复杂度，作为避坑样本 |
| [AnythingLLM](https://github.com/Mintplex-Labs/anything-llm) | 桌面/Web/Mobile 产品分层、Provider adapter、隐私/telemetry 说明 | RAG、Agent、向量库和默认遥测/CDN 复杂度 | MIT；支持 opt-out telemetry，部署时必须明确数据和外部连接边界 |

## D-006：当前技术选型

- 客户端：Flutter/Dart + Riverpod；复用现有五端代码，但本阶段只验证
  Android。
- 本地状态：Drift 只保存客户端读模型、游标、草稿和本地历史；Gateway/
  PostgreSQL 仍是远程工作事实权威。
- 凭据：Android Keystore 通过现有 `flutter_secure_storage`；数据库只保存
  opaque 引用，不保存 API key、Gateway token 或设备私钥正文。
- 传输：生产只允许 HTTPS/gRPC/TLS；明文 loopback 仅测试 factory。
- 语音：现有 `record` 内存 PCM 端口、远程 STT adapter、provider-neutral
  TTS；不增加 Pipecat/LiveKit。
- 发布：Android release variant 必须先能构建，再等待用户提供或配置正式
  signing authority；debug signing 不能写成发布证据。

## D-007：当前证据与外部输入

截至 2026-08-13，本轮已确认：

- Android 主 manifest 同时包含 `INTERNET` 和 `RECORD_AUDIO`；release
  manifest merge 与 `assembleRelease` 成功；
- Flutter analyze、生成物 freshness、format、客户端测试通过；
- Node/协议/Gateway/服务端质量门、全量离线测试和 transport loopback 门通过；
- 仍缺 Android 实体设备、release signing、真实 Hermes 0.20 Gateway 纵向
  链路、远程 STT/TTS 和完整发布门；
- 当前 MCP/codebase-memory 有重复注册/历史索引，agent-reach doctor 会因
  环境不可写失败。这属于开发环境修缮项，不能改写成产品代码完成。

后续每一轮开发只追加新的决策或证据，不覆盖历史结果；若新证据推翻本文件
中的取舍，先新增一条 `Supersedes D-xxx` 决策，再修改 PRODUCT/ARCHITECTURE/
DELIVERY 对应章节。

## D-008：Android 语音输入采用既有 adapter 的明确同意式 HTTPS 变体

- 日期：2026-08-13
- 状态：Implemented locally / live provider unverified
- 决策：Android 生产 VoiceFactory 接入已有 `ConsentedRemoteSttPort`，使用
  精确 HTTPS origin、provider ID、TLS policy、retention policy、contract
  revision 和显式 consent timestamp。录音仅在前台停止录音后以内存 PCM 一次性
  上传；不在手机启动本地 STT sidecar，不做后台常听或未经同意的上传。
- 凭据：remote STT token 使用独立的 `RemoteSttSecretStore` 写入 Android
  OS-backed secure storage；普通 voice settings 只保存 provider disclosure，
  不保存 token。provider ID 只作为 opaque secure-storage key，不参与授权判断。
- 复用：沿用 `remote_stt_port.dart` 的 bounded JSON HTTPS transport、精确 origin
  校验、无正文错误和录音上限；沿用 `VoiceSessionController` 的 editable final
  transcript、STT 失败保留既有草稿和 generation/cancel 语义。
- 避开：不引入 Pipecat/LiveKit、不新增 provider registry、不把远程 STT token
  与 Gateway/Hermes 或 Direct LLM credential 混用；不把离线 fake transport
  或 Flutter tests 写成真实服务验收。
- 验收边界：配置 round-trip、token 隔离、生产工厂注入和 UI 同意流程已有离线
  测试；具体 provider 的真实 HTTPS、TLS、留存承诺、中文识别质量、断网恢复和
  实体 Android 麦克风仍需单独 live 验收。

## D-009：设备门保持为外部验收门，不用模拟环境替代

- 日期：2026-08-13
- 状态：Open / external dependency
- 证据：宿主机 `adb start-server` 成功，但 `adb devices -l` 返回空设备列表；
  当前环境没有可安装和操作的实体 Android 设备，也没有可用 AVD。项目 doctor
  能看到 Hermes CLI `v0.20.0`，但 `127.0.0.1:8642/health` 无监听服务，且当前
  shell 没有可用的 `HERMES_*` 凭据环境变量。
- 决策：继续保持 Android shell、配对、文本、麦克风权限、远程 STT 和恢复的
  实机门未关闭。允许继续完善离线实现和自动化准备，但不得把 APK 构建、Flutter
  widget 测试或 fake transport 写成设备验收结果。
- 下一步输入：一台开启 USB debugging 的具名 Android 设备，或一个可启动的
  API 级别符合项目下限的 AVD；同时需要隔离的真实 Hermes/Gateway 和远程 STT
  测试服务，才能执行下一阶段纵向验收。

## D-010：Android 实机已接通，但配对验收必须先修正 CA 信任材料输入

- 日期：2026-08-13
- 状态：Open / device reachable, pairing unverified；supersedes D-009 的
  “无实体设备”现场判断，不改变其“不能用模拟结果替代实机结论”的原则。
- 证据：`adb -s 100.96.66.108:5555` 返回在线设备，型号 `V2359A`、Android
  16；当前 release APK 已安装并能启动，首屏正确显示未配对状态。为本仓库临时
  创建的隔离 Gateway、mock Node 和临时 PostgreSQL 可运行，未连接 Hermes。
- TLS 取舍：继续使用客户端已有的 `ChannelCredentials.secure` 与显式导入 CA；
  不增加 `onBadCertificate`，不放宽 TLS 校验。隔离测试证书需同时覆盖测试网关
  实际连接地址、给定的 Tailscale IP/DNS SAN，并由 Android 明确建立信任。
- 当前阻塞：Android 配对页只有多行 PEM 文本输入；ADB 分段注入长证书时
  Flutter 输入焦点会丢失并误触发提交，客户端安全地显示
  `gateway_setup_failed`。这次结果不能证明 Gateway RPC 或生产 TLS 实现失败，
  也不能写成配对通过。
- 下一步：改用 Android 用户证书安装或受控的 debug-only CA 导入方式后，只做一轮
  配对验收；若仍失败，记录具体 TLS/RPC 错误并停止，不重复盲试同一安全错误码。

## D-011：配对页采用 Android 文件导入承载私有 CA

- 日期：2026-08-13
- 状态：Implemented locally / device pairing unverified；supersedes D-010 的
  “下一步”取舍，不改变其失败证据。
- 决策：在配对页增加 Android `ACTION_GET_CONTENT` 文件导入，读取上限为
  128 KiB，Dart 端严格要求 UTF-8 PEM certificate block，导入后继续走现有的
  `ChannelCredentials.secure(certificates: ...)` 显式 CA 路径。
- 原因：Android 系统用户 CA 是设备全局状态，当前厂商文件选择器看不到通过 ADB
  直接写入 Download 的原始文件；同时没有证据证明 `networkSecurityConfig` 会
  改变 Dart gRPC 使用的 `SecurityContext`。文件导入能解决多行输入焦点问题，且
  保留每个 Gateway profile 的显式信任边界。
- 安全边界：不增加 `onBadCertificate`，不接受私钥，未通过 PEM 格式和大小检查的
  文件拒绝；文件内容不进入日志，取消和读取失败只展示固定安全文案。手工 PEM
  输入作为桌面/备用路径保留。
- 退出路径：文件选择器仅是 UI 入口；证书信任仍由 `GatewayGrpcChannelFactory`
  解析，未来可替换为另一种 OS 文件 API 而不改变 pairing/workflow 契约。
- 验收边界：离线 helper/widget 和 Android release build 通过后，仍必须在真实
  Tailscale 设备上完成一轮配对；未完成前不得宣称文本、断线恢复或远程 STT 已通过。

## D-012：修复生产配对默认 user-code 生成器的挑战长度冲突

- 日期：2026-08-13
- 状态：Implemented locally / real BeginPairing verified；owner approval pending
- 证据：真实 Android 请求在 TLS 入口修复后仍未入库；同一临时 Gateway 的主机
  `BeginPairing` 诊断调用返回 `[internal] internal error`。直接调用同一
  `PairingCoordinator.begin` 得到异常栈：`Challenge size must be between 16 and
  128 bytes`。生产默认 `newUserCode` 使用 `newChallenge(8)`，而密码学 helper
  的最小挑战长度是 16；现有单元测试注入了自定义 `newUserCode`，因此没有捕获该
  默认路径缺陷。
- 决策：保留现有 8 字符 user-code 格式和校验，改为生成 16 字节随机输入后取前
  8 个字符，并增加不注入默认依赖的回归测试。这样修复默认运行时路径，不降低
  challenge/nonce 的密码学长度约束，也不改变 TLS、scope 或 owner approval。
- 环境边界：Fedora public firewalld 拒绝手机到新高位端口；本次临时验收用
  Tailscale raw TCP 443 → loopback Gateway 18653，透传 TLS，不终止或放宽证书校验。
  该转发和临时数据库只属于验收环境，不能替代生产网络部署结论。
- 下一步：通过 Node/Gateway 质量门后重建隔离环境，只提交一次新的 Android
  `BeginPairing`；成功后停在人工 owner approval，再继续文本和断线恢复，最后才
  验收远程 STT。

## D-013：待 owner 审批阶段提供本地放弃入口

- 日期：2026-08-13
- 状态：Implemented locally / required for live acceptance recovery
- 证据：旧隔离 Gateway 进程退出后，owner 私钥不再存在；随后重建临时
  PostgreSQL，旧 pairing 记录已明确不存在，但 Android 仍保留
  `AWAITINGOWNERAPPROVAL` checkpoint。现有 coordinator 支持安全 `abandon`，
  但 UI 只在 `uncertain` 阶段暴露入口，无法清理这一类已失效的本地 pending
  pairing。
- 决策：在 owner approval 页面增加 `Abandon local pairing attempt`，复用现有
  `DevicePairingController.abandon`。该操作只删除本地 pending key/checkpoint，
  不发送 approval、Complete 或任何 Agent 命令；重新提交必须重新导入 CA，并在
  新 user-code 上重新经过独立 owner approval。
- 取舍：不使用 `pm clear`，避免删除测试包无关的草稿和设置；不通过数据库伪造
  旧 pairing 或重建 owner 私钥。该入口保留“每个审批门停下”的安全语义。

## D-014：真实配对验收使用同一存活 harness，审批前停在人工门

- 日期：2026-08-13
- 状态：Implemented locally / new owner approval pending
- 证据：在同一前台 harness 会话中重建隔离 Gateway、mock Node 和临时
  PostgreSQL；harness 启动时重新生成 owner key 并完成 bootstrap。Android 设备
  `V2359A` 通过 Tailscale `100.96.66.108:5555` 重新导入测试 CA，并向
  `https://100.103.253.87` 成功提交一次新的 `BeginPairing`。临时数据库当前仅有
  一条 `pending_owner` 记录，pairing id 为
  `pairing_f7947781-5fd9-49c0-8521-863f7d578e9d`，requested scopes 为
  `{observe,send}`；harness 持续输出 `MOCK_NODE_HEARTBEAT=ok`。
- 决策：owner 私钥只存在于当前前台 harness 生命周期内；收到新 user-code 后
  必须先停在人工审批门，等待 owner 独立核对并明确批准，才能在同一 harness
  会话发送 `approve`，随后继续 Complete/Confirm、文本会话、断线恢复和远程
  STT。不得自动审批、重建旧私钥、伪造数据库状态或把 mock Node 证据写成 Hermes
  实机证据。
- 取舍：本记录不持久化一次性 user-code 或 owner credential；代码已通过当前
  会话直接报告给 owner。若本轮因人工审批暂停，必须保留前台 harness，不得让
  进程随会话结束而丢失 owner key。

## D-015：Android 无线调试与私网连接采用成熟组件组合，不自研网络层

- 日期：2026-08-13
- 状态：Research complete / reference only；未引入依赖或代码
- 调研范围：通过 GitHub 只读读取项目元数据、许可证、README 和相关连接/TLS
  文档；未克隆、未修改外部仓库，也未把这次调研当作完整代码安全审计。
- 参考项目：
  - [tailscale/tailscale-android](https://github.com/tailscale/tailscale-android)：
    Tailscale 官方 Android 客户端，BSD-3-Clause，当前仓库活跃；定位是基于
    WireGuard 的私有网络，已有 Android 构建、发布和设备 ADB 连接文档。复用其
    “网络底座由成熟 VPN 客户端负责”的边界，不把 Tailscale/控制面嵌入
    Agent_Talk。
  - [WireGuard/wireguard-android](https://github.com/WireGuard/wireguard-android)：
    Apache-2.0，GitHub 镜像指向官方 WireGuard 仓库；采用内核实现并在无 root
    场景回退 userspace 实现。只有未来替换 Tailscale、需要自建 VPN 时才评估，
    当前 Android MVP 不重复实现 VPN/VpnService。
  - [Genymobile/scrcpy](https://github.com/Genymobile/scrcpy)：Apache-2.0，
    活跃的设备诊断/控制工具；其文档明确支持 ADB TCP/IP、以 `ip:port` 作为
    设备 serial，并强调设备端不留安装物。可复用设备选择、显式 serial 和无线
    诊断思路，不把 scrcpy 作为产品运行时通道。
  - [grpc/grpc-java](https://github.com/grpc/grpc-java)：Apache-2.0，活跃的
    gRPC/HTTP2 实现；Android 推荐 `grpc-okhttp`，并提醒在创建 channel 前准备
    Dynamic Security Provider 或 Conscrypt，以确保 TLS/ALPN。它用于校验当前
    gRPC/TLS 方向，Flutter 仍沿用仓库已有 Dart ConnectRPC 架构。
- 结论：运维侧继续使用 Android 11+ Wireless Debugging 的 TLS 配对并固定
  `adb -s 100.96.66.108:5555`；产品运行时只依赖 Tailscale 私网路由、精确
  Gateway HTTPS origin/SAN、显式 CA 和应用层设备凭据。避免自定义 ADB daemon、
  自动端口扫描/发现、全局安装测试 CA、`onBadCertificate` 或把 ADB 作为应用
  数据通道。该组合解决了“设备可达”和“应用可信连接”两个不同问题，保留可
  替换的网络底座出口。
- 安全判断：候选项目均有明确许可证和公开维护证据；本次只做仓库级筛选，未对
  候选项目逐行审计。任何引入前仍需记录版本、许可证、供应链来源、权限和退出
  路径。

## D-016：harness 改为 setsid + FIFO 托管，新的审批门使用新 user-code（已由 D-017 更新）

- 日期：2026-08-13
- 状态：Implemented for live acceptance / superseded by D-017
- 证据：旧 `BLF7-G3SC` 随 harness 退出而失效，未尝试迁移旧 owner 私钥或伪造
  审批。临时 PostgreSQL 的 `agent_talk` schema 已重建；新隔离 harness 由
  `setsid` 启动，PID `216869` 的 PPID 为 `1024`，SID/PGID 均为自身，日志在
  `/tmp/agent-talk-live-20260813.log`，人工命令 FIFO 在
  `/tmp/agent-talk-live-20260813.fifo`，并持续输出 `MOCK_NODE_HEARTBEAT=ok`。
  Android `V2359A` 通过 `adb -s 100.96.66.108:5555` 重新导入 CA 并提交新的
  `BeginPairing`；数据库唯一记录为 pairing id
  `pairing_b00d093a-1272-4636-acc2-8bb4bae961b4`、状态 `pending_owner`、
  scopes `{observe,send}`。
- 决策：新的 user-code `P2GJ-GGS2` 已报告 owner，当前必须停在人工审批门。
  收到 owner 对这个新 code 的明确批准后，才可向 FIFO 投递
  `approve P2GJ-GGS2 observe,send`，然后继续 Complete/Confirm、文本会话、
  断线恢复和远程 STT。每个后续审批门仍需再次停下；Hermes 保持零改动，mock
  Node 只作为隔离控制面，不能写成 Hermes 实机证据。

## D-017：owner 批准后，先关闭 Android 配对与 mock 文本/恢复门，再停在远程 STT consent 门

- 日期：2026-08-13
- 状态：Android 配对、文本和客户端断线恢复已通过；真实 Hermes 与远程 STT 未关闭
- 证据：owner 明确批准 `P2GJ-GGS2`（`observe,send`），harness FIFO 记录了对应的
  `OWNER_APPROVAL=approved`。手机完成 Complete/Confirm 后，PostgreSQL 中同一
  pairing 为 `confirmed`，device/credential 为 `active`，scope 为 `{observe,send}`；
  UI 显示 `Connected` 与 `Authenticated Gateway stream is active`。这只证明
  Agent_Talk → 隔离 Gateway → mock Node 的真实 Android 控制面，不证明 Hermes。
- 文本结论：手机创建隔离 mock Agent 会话、明确获取 control lease、编辑并显式
  Confirm 后发送无害测试短句；UI 显示 `Control held by this device`、`Request
  completed` 与 mock Node 完整回复。数据库 request 为 `completed`，事件序列为
  `request.accepted → agent.working → message.completed → request.completed`，
  未出现第二次 dispatch。
- 恢复结论：主动 Disconnect 后 UI 显示 `Not connected`，提示未重发 uncertain
  submission；重新 Connect 后 Gateway stream、历史 mock 回复和 `Request completed`
  恢复。期间发现并修复已 accepted request 在 stream close 时被错误标记 uncertain
  的 UI 状态污染，并以定向测试覆盖。该门的实测范围是客户端 stream 断开/重连和
  事件恢复，不等同于物理断网或 Hermes run 恢复。
- 安全边界：未触碰 Hermes、未 push、未自动批准任何后续请求；测试环境仍只走
  `adb -s 100.96.66.108:5555` 和 Tailscale HTTPS。mock Node、临时 PostgreSQL、
  测试证书和 harness 都不属于生产部署证据。

## D-018：设备凭据过期时使用已有签名 Refresh RPC，协议 minor 采用协商结果

- 日期：2026-08-13
- 状态：Implemented locally / Android profile live verified
- 决策：客户端在打开已配对 Gateway 前检查 access expiry；过期时使用设备密钥对
  `credential-refresh/v1` payload 签名，调用既有 `RefreshDeviceCredential`，校验
  identity、audience、scope、token 格式和新 expiry 后按 generation 轮换安全存储，
  再建立 live stream。不得以放宽 bearer/TLS 校验或静默重新配对替代 refresh。
- 原因：实机复现 Confirm 后短期 access token 到期时，客户端把 refresh-capable
  credential 直接当作 invalid，导致已配对设备无法恢复。修复后定向 Flutter 测试
  通过，profile APK build number `2002` 实机显示 Connected；最终 build number
  `2003` 通过系统外部来源确认后安装，重新连接和历史恢复均通过。
- 协议：客户端接受 Gateway 协商的 protocol minor `0..1`；先前仅接受 `0` 与
  Gateway 当前选择的 `1` 冲突，已加入 minor `1` 回归测试。协议 major、schema
  hash、capability、scope 和 TLS 校验仍 fail closed。
- 取舍：credential generation 写入 secure storage 以支持轮换后的单调更新；旧
  token 不写日志、不在文档保存。刷新 RPC 失败保持明确连接失败/不确定语义，不
  自动重发用户命令。

## D-019：远程 STT 暂停在真实 provider 与用户 consent 输入门

- 日期：2026-08-13
- 状态：Blocked / external provider and explicit consent required
- 证据：最终 Android 设置页显示 `STT provider / Disabled`，`Test STT readiness`
  不可用；可选项明确为 `Consented HTTPS provider (Android)`。当前没有真实
  provider origin、provider token、retention disclosure 和用户明确 consent，
  因而没有上传音频，也没有把 fake/离线测试写成远程 STT 实机通过。
- 决策：保持远程 STT 默认关闭，停在此门等待 owner/user 提供真实 provider 与
  允许上传的明确 consent；随后仍需单独验收 TLS/origin、Android microphone
  permission、中文识别、断网恢复和完整文字降级。不得填充占位 token、勾选 consent
  或自动保存远程配置。

## D-020：用现有 faster-whisper backend 补齐 Android 验收所需的 HTTPS provider 表面

- 日期：2026-08-13
- 状态：Provider preparation complete / Android installation gate blocked
- 发现：`services/stt` 原有 `voxhandoff-stt` 是 versioned stdio JSONL sidecar，
  而 Android `JsonHttpRemoteSttTransport` 只调用 `/v1/health` 与
  `/v1/transcribe`。二者之间没有可直接启动的 HTTPS provider，不能把 stdio
  进程或 fake transport 写成远程 STT 实机证据。
- 决策：新增窄 HTTPS adapter，复用 `SttBackend` 和 `SttService` 的音频/临时
  WAV/错误边界；默认只监听 loopback，启动前加载明确的本地
  `/home/roco/.cache/faster-whisper-base` 模型；转写要求独立 Bearer token，
  JSON/分块请求和音频均有上限；TLS 使用明确证书、最低 TLS 1.2，不提供
  `onBadCertificate`、明文 HTTP、模型下载或 PATH 命令入口。
- 调试信任：Android manifest 增加 `networkSecurityConfig`，release/base 只信
  system roots，`debug-overrides` 才允许 user CA。当前测试证书链验证通过，SAN
  覆盖 `100.103.253.87`、`100.96.66.108` 与 `v2359a.tailbd75d3.ts.net`。
- 证据：services/stt 离线测试 `14` 项通过；本地 faster-whisper-base warmup
  成功；HTTPS `GET /v1/health` 在 loopback 与 Tailscale 443→18654 临时转发
  均返回 `status=ready`。服务由独立 session 托管，运行日志位于临时目录，
  token 未写入项目或文档；经 Tailscale HTTPS smoke 验证，POST 无 token 返回
  `401`，带独立 token 但 malformed body 返回 `400`，未发送音频。
- 当前门：profile APK 已构建，但 Android 系统仍停在“来自未知来源 / 继续安装”
  确认页，尚未安装新 network config。设备此前未显示测试 CA 的系统用户信任记录，
  因而不能继续声称手机 readiness、真实录音或上传已通过；下一步必须由用户确认
  系统安装，并在必要时由用户完成 CA 信任确认，然后才进入 provider consent、
  microphone permission、中文识别和断网恢复门。

## D-021：profile APK 已完成非流式安装，但未取得本轮新的系统确认交互证据

- 日期：2026-08-13
- 状态：Installed / human confirmation evidence not freshly observed
- 证据：首次 `adb install --no-streaming -r` 因设备已有 `versionCode=2003` 而返回
  `INSTALL_FAILED_VERSION_DOWNGRADE`；随后使用保留应用数据的 `-d` 重试，文件以
  35.6--36.4 MB/s 传输并返回 `Success`，设备当前安装包为 debug/profile、
  `versionCode=1`，`RECORD_AUDIO` 仍未授权。此次重试没有出现新的“来自未知来源 /
  继续安装”弹窗，前台仍是系统 Launcher；因此不能把 adb 成功当成本轮用户确认
  交互证据。
- 决策：暂停应用启动、provider 配置、token 输入、readiness、麦克风和音频上传，
  等待用户确认已接受本次安装结果后再继续。STT HTTPS 服务、Tailscale
  `443→18654`、Gateway harness 继续保持运行；Hermes 不变。

## D-022：Android 远程 STT 表单已填入真实测试 provider，停在人工 consent 门

- 日期：2026-08-13
- 状态：Configured in UI / awaiting explicit user consent
- 证据：已启动实体 Android `V2359A` 上的 profile APK，在 Voice settings 选择
  `Consented HTTPS provider (Android)`。当前表单显示 provider ID
  `voxhandoff-stt`、origin `https://100.103.253.87`、TLS disclosure
  `debug user ca hostname verified tls12`、retention disclosure
  `local test provider audio transient memory only no persistence`、revision
  `voxhandoff-http-v1`。独立测试 token 从临时权限受限文件逐字符输入，UI 仅显示
  64 个掩码字符，token 未进入日志、spec 或诊断输出。
- 安全门：`I consent to this exact upload disclosure` 当前仍为
  `checked=false`；未点击复选框、未保存远程配置、未上传音频。controller 只对
  已保存且 `consentedAt` 非空的远程配置构造生产 port，当前不能把 readiness
  点击结果冒充 provider readiness。
- 下一步：等待用户/布洛妮娅在手机上勾选当前 disclosure，并完成 `Save STT settings`；
  随后执行 readiness、真实麦克风权限门、中文录音/转写/确认和断网恢复。STT 服务
  PID `281299`、Tailscale `443→18654` 和 Gateway harness 仍保持运行，Hermes
  零改动。

## D-023：Android 远程 STT readiness 在真实 TLS 信任门失败，暂停录音

- 日期：2026-08-13
- 状态：Blocked / Android client TLS trust path
- 证据：重新打开实体 Android `V2359A` 的 Voice settings 后，provider ID、HTTPS
  origin、TLS/retention/revision disclosure 均回显，consent 复选框为
  `checked=true`，`Save STT settings` 与 `Test STT readiness` 均为 enabled。该 UI
  round-trip 证明同意配置已保存；客户端没有把 `consentedAt` 的原始时间戳展示在
  诊断 UI 中，因此本条不伪造具体时间戳。
- readiness 实测：连续点击真实 `Test STT readiness` 后，UI 显示固定安全错误
  `The local STT service could not be reached.`。同一时间段 STT HTTPS 服务没有新增
  Android `/v1/health` 访问记录；设备到 `100.103.253.87` 的 Tailscale ICMP 可达，
  但这不能替代 TLS/HTTP 证据。服务端在宿主机 loopback 和 Tailscale 入口的独立
  `curl --cacert` 健康检查仍返回 `status=ready`，所以 provider 进程和入口本身
  已就绪，失败发生在 Android Dart HTTPS 请求到达 HTTP 之前。
- 诊断边界：安装包 `versionCode=1`、`DEBUGGABLE`、`targetSdk=36`，应用的
  `RECORD_AUDIO` 当前仍为 `granted=false`。现有 `networkSecurityConfig` 的
  `debug-overrides` 只覆盖 Android 平台信任配置；Dart `HttpClient` 是否消费该
  信任路径、以及测试 CA 是否存在于 Android 用户证书库，尚未得到设备端直接证据。
  因此暂定为 Android TLS trust-path 阻塞，不把它误判为 provider 宕机，也不使用
  `onBadCertificate` 或明文连接绕过。
- 决策：在 readiness 未通过前不触发麦克风权限、不录音、不上传音频、不进行中文
  转写/终稿确认，也不执行断网恢复测试；否则无法区分真实 STT 失败与未建立安全
  连接。下一步需要修复或明确 Android Dart 客户端的 CA 信任输入（保留证书链和
  主机名校验），再重新安装并从 readiness 门继续。Hermes、Gateway harness、
  mock Node 和临时 PostgreSQL 均未被本条改动。

## D-024：Dart 远程 STT 显式复用已导入 Gateway CA

- 日期：2026-08-13
- 状态：Implemented locally / Android installation confirmation pending
- 决策：`JsonHttpRemoteSttTransport` 新增可选的显式信任根参数；存在时创建
  `SecurityContext(withTrustedRoots: true)`，通过
  `setTrustedCertificatesBytes` 注入配对页导入并由
  `SecureGatewayConnectionProfileStore` 保存的 PEM CA，再创建标准 `HttpClient`。
  这样同时保留系统根证书、默认 hostname/SAN 校验和 Dart TLS 最低安全行为。
- 取舍：不使用 `onBadCertificate`、不允许明文、不修改 Android
  `networkSecurityConfig` 来假定 Dart `HttpClient` 会消费它；未配对/无显式 CA
  时继续使用系统根证书。生产 voice factory 从同一 secure store profile 读取
  trusted roots，使 readiness 与转写使用相同的显式 CA 边界。
- 验证：`remote_stt_port_test.dart` 新增有效 PEM 注入和 malformed CA fail-closed
  测试；remote STT 与 production voice factory 定向测试共 `7` 项通过，Flutter
  analyze 对相关 `3` 个 Dart 文件无问题。profile APK 构建成功，SHA-256 为
  `efdad4e400d09bc32778222065b27e2d3bcfb8b9f3cc56a49f04d641e2cac9f8`，大小约
  `127 MB`。
- 当前门：通过指定 Tailscale ADB 执行 `adb install --no-streaming -r -d` 时，
  APK 已传输约 `35.8 MB/s`，但 Android 前台停在
  `com.android.packageinstaller/.PackageInterceptActivity`，等待人工继续安装。
  在用户确认前不把 APK 写成已安装、不启动 readiness、不触发麦克风、不上传音频。
  Hermes 零改动，未 push。

## D-025：Android fresh-process readiness 仍未到达 provider，显式 CA 方案收窄

- 日期：2026-08-13
- 状态：Android readiness blocked / next profile installation confirmation pending
- 证据：owner 确认 D-024 profile 已安装后，实体 Android `V2359A` 新进程重新打开
  Voice settings；provider/origin/TLS/retention/revision 回显，consent 仍为
  `checked=true`，token 输入框保持空白掩码状态，符合不回填安全 token 的设计。新进程
  点击 `Test STT readiness` 后 UI 仍显示
  `The local STT service could not be reached.`，STT 服务日志没有对应新增
  `/v1/health` 请求。设备 Tailscale ICMP 可达，宿主机 Dart `SecurityContext` 使用
  同一测试 CA 请求 `https://100.103.253.87/v1/health` 返回 HTTP `200`。
- 诊断边界：应用私有加密存储中仍存在 Gateway profile 和独立 STT token 记录；本轮
  只做 key/记录长度存在性检查，没有解密或输出任何值。由此未把“token 丢失”或
  “provider 宕机”写成结论，Android runtime 的自定义 CA 路径仍未被实机 HTTP 证据
  证明。
- Supersedes D-024 的信任集细节：当显式 CA 存在时，`SecurityContext` 改为
  `withTrustedRoots: false`，只信任该 provider 的导入 CA，并显式设置最低 TLS
  `1.2`；没有显式 CA 时保持 `HttpClient` 平台系统根行为。证书链、SAN/hostname
  校验保持启用，没有 `onBadCertificate`、明文或信任旁路。该变体定向测试 `7` 项
  通过、Flutter analyze 无问题。
- 当前门：新变体 APK 已构建并传输，但 Android 再次停在
  `PackageInterceptActivity`，人工安装确认未代点；本轮未把该变体写成设备已验证。
  因 readiness 仍未通过，未触发麦克风、未录音、未上传、未转写、未确认终稿、未做
  断网恢复。Hermes 零改动，未 push。

## D-026：重新触发安装但未观察到 Android 人工确认交互

- 日期：2026-08-13
- 状态：Installation command succeeded / owner interaction unverified
- 证据：按 owner 指示再次执行
  `adb -s 100.96.66.108:5555 install --no-streaming -r -d`，APK SHA-256 为
  `a124008c8ec2fd288f4add546013e2126ce46430c15776f6f87d2acdfa6d2463`，无线传输
  约 `38.3 MB/s`，ADB 最终返回 `Success`。设备包元数据显示
  `lastUpdateTime=2026-08-13 21:11:55`、`DEBUGGABLE`、`targetSdk=36`；
  `RECORD_AUDIO` 仍为 `granted=false`。
- 人工门证据：本次安装等待期间未观察到
  `com.android.packageinstaller/.PackageInterceptActivity`，前台保持
  `com.bbk.launcher2/.Launcher`。因此不能证明 owner 点击了系统确认，也不把 ADB
  `Success` 等价为人工确认。
- 决策：不启动应用、不点击 readiness、不触发麦克风，停在 owner 需要确认安装
  结果的门上。owner 明确确认后，才继续启动、配置回显、readiness、真实中文录音、
  编辑/确认和断网恢复。Hermes 零改动，未 push。

## D-027：Android 窄信任集 STT 实机验收到达服务，但被真实音频输入阻塞

- 日期：2026-08-13
- 状态：Partial / blocked at live microphone audio
- 共享信任根修复：发现 STT 进程原先使用的测试 CA 与手机配对 profile 导入的
  Gateway CA 不同；隔离 STT 已改用同一 Gateway CA 与私钥，证书仍包含
  `100.103.253.87`、`100.96.66.108` 和 Tailscale DNS SAN。服务只提供 HTTPS，最低
  TLS 版本保持 1.2。
- 配置回显证据：实体 `V2359A` 新进程启动后 UI 回显 provider
  `Consented HTTPS provider (Android)`、provider ID `voxhandoff-stt`、origin
  `https://100.103.253.87`、语言 `zh`、TLS/retention/revision 声明；token 输入框
  为空掩码且 secure storage 引用仍存在；consent 复选框为 `checked=true`。
- readiness 证据：手机 readiness 真实请求到达共享 CA 的 STT HTTPS 服务，UI 曾显示
  `Ready`；服务日志记录 `/v1/health` HTTP `200`。这证明窄信任集
  `SecurityContext(withTrustedRoots: false)`、显式 CA、TLS 1.2 和 SAN 校验链路已
  通过，未使用 `onBadCertificate` 或明文连接。
- 真实录音证据：点击 `Record voice draft` 后 UI 进入
  `Recording · speech remains editable before send`；本次未出现麦克风权限弹窗，
  Android 包状态显示 `RECORD_AUDIO: granted=true`。停止后手机真实向
  `/v1/transcribe` 发出请求，服务以 `422` 返回；安全诊断仅记录稳定错误码
  `stt_no_audio`，不记录音频、token 或转写正文。UI 显示
  `Remote speech recognition failed. No Agent request was sent.`，Editable draft
  为空、Confirm disabled。
- 结论：阻塞点是录音窗口内没有达到服务静音门阈值的有效 PCM，不能据此宣称中文
  识别质量、可编辑中文终稿或确认链路通过；没有使用 fake 音频、fake 文本或代点
  Confirm。下一次实机验收必须在确认 Fedora 外放音频确实开始后重新录音。
- 网络恢复子检查：Tailscale Serve 当前唯一 TCP 路由曾被 `tailscale serve reset`
  移除，命令结果为 `No serve config`；随后恢复为 `443 -> 127.0.0.1:18654`，
  `tailscale serve status` 与服务端多次 `/v1/health` HTTP `200` 均正常。断路期间
  手机端 30 秒 readiness 超时文案未单独捕获，因为路由在该请求完成前已恢复；因此
  只记录为 provider-route 级恢复证据，不冒充完整客户端离线恢复验收。
- 边界：Hermes 未修改，Gateway/mock Node/PostgreSQL 未被本阶段改动；设备仍只经
  `100.96.66.108:5555` Tailscale ADB，未 push，未自动审批，未提交或推送代码。

## D-028：最终中文外放录音轮仍未产生可识别 PCM

- 日期：2026-08-13
- 状态：Blocked / real microphone capture amplitude
- 操作：重新启动实体 `V2359A` 上的已安装应用，确认隔离 STT 服务和 Tailscale
  `443 -> 127.0.0.1:18654` 路由均存活；点击 `Record voice draft` 后确认 UI 进入
  `Recording · speech remains editable before send`，等待约 8 秒覆盖 5.4 秒外放
  音频窗口，再点击 `Stop and transcribe`。
- 结果：手机真实发出一次 `/v1/transcribe`，服务返回 `422`，安全诊断为
  `stt_http_error code=stt_no_audio status=422`。UI 显示
  `Remote speech recognition failed. No Agent request was sent.`；Editable draft
  为空，Confirm disabled。没有录入或输出伪造中文文本。
- 结论：本轮仍不能证明 Fedora 外放音频实际被手机麦克风以足够幅度采集；问题已
  不在 TLS、CA、SAN、token 或 readiness。中文转写、可编辑终稿、确认和完整断网
  恢复链路继续保持未通过。后续应先独立验证手机录音输入电平/音频路由，再重跑实机
  验收，不应继续重复相同录音动作。
- 边界：Hermes 零改动、未 push、未自动审批，设备只经
  `100.96.66.108:5555` Tailscale ADB；Gateway harness 与 STT 服务保持隔离存活。

## D-029：2026-08-14 真机验收停在新 CA 导入门

- 日期：2026-08-14
- 状态：Partial / blocked before Android readiness
- 证据：新隔离 STT HTTPS 服务已启动在 `127.0.0.1:18654`，宿主机 health 为 HTTP
  `200`、`status=ready`，Tailscale Serve 为 `443 -> 127.0.0.1:18654`；证书 SAN
  含 Tailscale DNS、`100.103.253.87`、`100.96.66.108`，无明文 HTTP。
- 客户端：用 Flutter `3.44.6` 构建 Debug APK，版本 `0.1.0+1`，SHA-256 为
  `779e1c89ccbd806bf6b55a99a5fa8b7ebcff9bc399508d6ea0bf88fa7dee360e`；指定
  Tailscale ADB 安装返回 `Success`，包为 `dev.agenttalk.agent_talk_client`，
  `lastUpdateTime=2026-08-14 08:48:23`，未出现或代点 `PackageInterceptActivity`。
- 配置：Voice settings 真实回显 `voxhandoff-stt`、
  `https://100.103.253.87`、`zh`、consent `checked=true`；新 token 已写入密码字段
  并保存，值未进入证据。`RECORD_AUDIO` 为 `granted=true`。
- 阻塞：点击 `Test STT readiness` 的 UI 安全文案为
  `The local STT service could not be reached.`，服务端没有新增 Android health
  请求，说明手机仍未信任新 CA。旧 Gateway profile 仍 paired，当前应用只有
  `Connect Gateway`，Private CA picker 没有可达的重新配对/编辑入口。本轮不清除
  app data，不读取或注入 secure storage，不使用 TLS 旁路。
- 结论：未开始真实录音，故没有 `bytes/rms`、转写、可编辑终稿或 Confirm 证据；不把
  宿主机 HTTP 200 或 token 保存写成移动 readiness 通过。下一步是通过 pairing UI
  重新导入新 CA 并完成必要的 owner 人工门，然后重启 app 重新验收。Hermes 零改动，
  未 push。

## D-030：2026-08-14 已配对 CA 重导入入口完成，但 STT 认证阻塞录音

- 日期：2026-08-14
- 状态：Partial / blocked at remote STT authorization
- 决策：在 Voice settings 的 Hermes 区域提供 `Re-import trusted CA`。导入服务复用
  `PrivateCaCertificatePicker` 的 PEM、私钥和大小校验，读取现有 secure Gateway
  profile，保留 Gateway audience，构造并校验新 profile 后再保存；未配对或 profile
  无效时拒绝保存并显示安全错误。生产 remote STT transport 改为在新请求创建时读取
  当前 profile 的 trusted roots，覆盖 CA 更新后的旧启动快照。
- 自动化证据：Dart format 通过，Flutter analyze 无问题；CA 导入成功/无效拒绝/未配对
  拒绝、factory 动态 CA 转发、transport 动态 CA、Voice settings 入口定向测试共 13
  项通过；全客户端测试 232 项通过，2 项预置 live smoke 跳过。
- 安装与配置证据：Flutter `3.44.6` Debug APK SHA-256 为
  `2565abe515b5b1bae3f921bf5f52a3f206090159596274b2f948138c292f1309`；通过
  `100.96.66.108:5555` Tailscale ADB 安装成功，`lastUpdateTime=2026-08-14 09:03:29`。
  UI 显示新入口，选择新 CA 后显示 `Trusted CA imported. Test STT readiness again.`；
  readiness UI 显示 `Ready`，服务端有 4 行 health `GET` 200。
- 真实录音证据：唯一一次录音进入 Recording，停止后 UI 显示
  `Remote speech recognition failed. No Agent request was sent.`；服务端只收到
  `POST /v1/transcribe` 401，认证失败发生在音频 payload 解析前，没有
  `stt_audio_stats`，因此 bytes/rms、中文转写、Editable draft、Confirm 均未取得。
  按任务书未重录，也没有伪造任何音频或文本结果。
- 当前门：需核对并由 owner 重新提供与当前 STT 服务一致的 provider token 后，才可
  重新进入录音验收；本轮不猜 token、不读取或输出 token，不改变服务认证策略。临时
  注入到设备 Download 的 CA 文件已删除，secure profile 中的新 CA 保留。Hermes 零
  改动，未 push，未自动审批。

## D-031：2026-08-14 第三轮 token 对齐后仍在 STT 鉴权门失败

- 操作：从服务端受保护 env 文件读取 provider token，在手机 Voice settings 清空密码
  字段后逐字符重新输入并保存；未清除应用数据，token 值未写入日志、文档或报告。
- readiness：UI 显示 `Ready`；服务端 `stt.log` 新增
  `stt_http "GET /v1/health HTTP/1.1" 200 -`（line 10）。
- 唯一真实录音：日志立即记录“已触发录音，等待外放”，约 8 秒后停止并转写。UI 显示
  `Remote speech recognition failed. No Agent request was sent.`；服务端新增
  `stt_http "POST /v1/transcribe HTTP/1.1" 401 -`（line 11）。认证发生在音频解析
  前，没有 `stt_audio_stats`，bytes/rms 不可得；没有中文转写、Editable draft 或
  Confirm 证据。
- 结论：服务端仍未接受本次 provider credential，token 对齐验收未通过；按任务书不
  重录、不伪造成功。后续需由 owner 核对 credential 传递链路后另开任务。本轮 Hermes
  零改动、未 push、设备只经 Tailscale ADB，阶段日志为
  `/tmp/voxhandoff-acceptance-20260814.log`。

## D-032：原生 PCM 事件流必须等待 EventChannel sink 就绪

- 日期：2026-08-14
- 状态：Implemented locally / device installation blocked
- 决策：Android `start` 准备好 `AudioRecord` 后，若 EventChannel `eventSink` 尚未
  由 `onListen` 建立，不提前返回成功；保留 pending result，`onListen` 到达后再启动
  readLoop 并返回成功，2 秒仍未就绪则固定失败。原生以 `VoxHandoffAudio` 记录
  `readCount`、sink null、discarding 和 push 结果，最多记录前 20 次，禁止记录音频
  内容、token、证书。
- 证据：Kotlin/Dart 两个 channel 名一致；Dart 订阅顺序由 Flutter mock stream
  handler 断言覆盖；`_discarding` 源码核对只在 cancel/关闭路径置真。Dart format、
  analyze、录音定向测试 2 项、Kotlin 编译和 pinned Flutter 全量客户端门
  `232 passed / 2 skipped` 通过。
- 实机边界：Debug APK SHA-256 为
  `81a4c60b0ef4f6fefe1a65e6cf1dba5aee4a12d602567e91980979869b88e858`。Tailscale ADB
  推送后停在 `PackageInterceptActivity`，未代点系统确认；包更新时间未变，故本轮
  没有安装新包、没有取得本轮原生日志/服务端 bytes-rms/转写文本/UI 证据。
- 下一步：由 owner 手动完成系统安装确认后，只执行任务书规定的一次录音并抓取
  `VoxHandoffAudio` 与服务端脱敏诊断；若仍为 `bytes=0`，按 readCount/sinkNull
  结果继续定位。Hermes 零改动，未 push。
