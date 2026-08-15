# VoxHandoff 开发与交付规范

> **当前状态：Active / Android-first MVP（2026-08-13）**
>
> 2026-08-13 重新开启产品开发，但执行范围收敛为 Android 手机端单一纵向
> 链路。本文件的历史阶段和旧验收结果继续保留；新的执行计划以本节为准。
> 当前产品客户端支持 Android（当前优先）、iOS（后续）、macOS 和 Windows；
> Linux 仅作为 Hermes/Agent/服务端部署主机，不提供客户端。iOS、macOS/Windows
> 新功能、后台监听、唤醒词、全双工语音、本地手机 sidecar 和新 Agent 后端在
> Android MVP 通过前不进入开发。

## 0.1 Android-first 执行顺序

1. 工具链：清理重复 MCP/index，确认 Flutter、Android SDK、实体设备和签名
   环境；工具故障不能被误写成产品故障。
2. Android shell：前台启动、配对、凭据安全存储、撤销、断线和恢复。
3. 文本闭环：Gateway/Hermes 事件恢复、确认目标、lease、取消和 uncertain；
   Direct LLM 保持纯聊天路径。
4. 语音输入：前台按钮录音、远程 STT、可编辑终稿和明确确认；手机不运行
   本地 STT sidecar。
5. TTS/降级：在文本闭环稳定后接入一个明确的 TTS provider，并验证文字
   结果独立于播放失败。
6. 实体 Android 验收：安装、配对、重启、断网、重连、权限、连续交互、日志
   脱敏和发布构建。

本轮只开发 Android 客户端；macOS/Windows 后续按同一阶段顺序适配，iOS 在后续
移动端阶段适配；Linux 客户端不做，Linux 仅作为 Hermes/Agent/服务端部署主机。

每个阶段都必须有可复现检查和独立结果；失败、阻塞和未验证不能写成完成。

### 0.1.1 2026-08-13 当前迭代证据

- 规格基线已从永久归档切换为 `1.65 Active / Android-first MVP`；产品、架构、
  交付和客户端说明均固定 Android 单平台优先范围。
- Android 主 manifest 补齐 release 变体所需的 `INTERNET` 权限，并保留
  `RECORD_AUDIO`；`./gradlew --no-daemon :app:processReleaseMainManifest` 成功。
- Android `:app:assembleRelease` 成功，产出 release APK；当前
  `apps/client/android/app/build.gradle.kts` 仍使用 debug signing config，
  所以这只是 release variant 构建证据，不是签名发布证据。
- Android `:app:lintRelease` 通过，未发现 lint 错误；Gradle 输出的 Kotlin/AGP
  built-in Kotlin 弃用提醒和 SDK XML 版本提醒属于后续工具链维护项，不改变
  当前 Android MVP 的功能或安全验收结论。
- 固定 Flutter 3.44.6 quality gate 通过：Dart protocol analyze、Drift
  generated-file freshness、format、Flutter analyze 和客户端测试全部通过；
  本轮最终结果为 223 项通过、2 项显式 live provider smoke 跳过；新增 Android
  remote STT disclosure/token 隔离、生产 VoiceFactory 注入和设置入口回归。
- Android remote STT 已接入生产工厂：精确 HTTPS origin、TLS/retention/revision
  disclosure 和 consent timestamp 进入本地 settings，token 单独进入 secure
  storage；录音停止后由既有 VoiceSession 以内存 PCM 调用 bounded provider adapter，
  STT 失败仍保留可编辑文字草稿。离线配置、UI 和工厂测试通过，真实 provider 未验收。
- `npm run check` 和 `npm test` 通过；包含 repository consistency、protocol
  contract/generated、TypeScript、Gateway/Node、STT 与 benchmark 门。
- `AGENT_TALK_LOOPBACK_INTEGRATION=1 npm run test:transport` 在允许 loopback
  的本地环境通过：Gateway 两项真实 HTTP/2/TLS 门，以及 Node 生产流持续超过
  60,000 ms 的门均通过。
- 当前仍未关闭：Android 应用重启、物理断网、权限/麦克风/远程 STT/TTS、Hermes
  0.20 真实 Gateway 纵向链路、release signing、MCP 重复注册和 agent-reach
  环境修复。客户端主动 stream 断开/重连与隔离 mock 文本闭环已在后续本轮证据中
  关闭。实体设备现已在线：`adb -s 100.96.66.108:5555` 识别到 `V2359A` /
  Android 16，release APK 已安装并成功启动，首屏未配对状态符合预期。
- 本轮为手机验收创建了仅供 Agent_Talk 使用的隔离 HTTPS Gateway、mock Node 和
  临时 PostgreSQL；Hermes 未启动、未发送请求、未修改配置或数据。测试 CA 已
  按给定 Tailscale IP/DNS SAN 重建，客户端仍坚持显式 CA 信任和严格 TLS 校验。
- 历史配对尝试中，Android 多行 PEM 字段在 ADB 分段输入长证书时丢失输入焦点，
  提交结果为 `gateway_setup_failed`；该结果不能证明 Gateway 或 TLS 实现失败。
- D-011 的 CA 文件导入路径已完成验证：`ACTION_GET_CONTENT` 启动标准
  `com.android.documentsui/.picker.PickActivity`，选择登记的测试 CA 后回到
  `MainActivity`，配对页显示完整 PEM；Android 侧限制 128 KiB，Dart 侧拒绝非
  UTF-8、非 PEM certificate block、各类私钥和超限输入。导入后仍使用显式
  `ChannelCredentials.secure` CA，不设置 `onBadCertificate`。
- D-012 的配对默认依赖缺陷已修复：生产 `newUserCode` 不再调用低于密码学
  helper 下限的 `newChallenge(8)`，Gateway 全套 14 组测试通过，并新增默认依赖
  回归测试。该修复不改变 user-code 格式、TLS 校验、scope 或 owner approval。
- 由于 Fedora public firewalld 拒绝手机到新的高位 Tailscale 监听端口，本轮临时
  使用 Tailscale raw TCP 443 → loopback Gateway 18653；主机经 443 的 TLS 自检为
  `Verification: OK`，该转发不终止 TLS，测试证书仍覆盖 Tailscale IP/DNS SAN。
- 真实 Android 已通过文件导入 CA、显式 TLS、Tailscale 443 入口提交
  `BeginPairing`；UI 进入 `AWAITINGOWNERAPPROVAL`，临时 PostgreSQL 有一条
  `pending_owner` 记录，设备名为 `This device`，requested scopes 为
  `{observe,send}`。owner approval 仍是人工安全门，未自动批准；因此完整配对、
  文本会话、断线恢复、麦克风和真实远程 STT 仍未验收，不能把 mock Node 证据写成
  Hermes 实机证据。
- 旧 harness 退出后其 owner 私钥不可恢复；重建临时 PostgreSQL 后，旧
  `X5SZ-TSWR` pairing 不存在，未执行伪造审批。新增 D-013 的本地 abandon 入口后，
  本轮在同一前台 harness 会话内重新 bootstrap owner、重新导入
  `agent-talk-live-ca.crt`，并以 `https://100.103.253.87` 提交一次新的
  `BeginPairing`。数据库证据为一条 `pending_owner` 记录：pairing id
  `pairing_f7947781-5fd9-49c0-8521-863f7d578e9d`、设备名 `This device`、scope
  `{observe,send}`；harness 连续输出 `MOCK_NODE_HEARTBEAT=ok`。手机 UI 显示
  新的一次性 user-code 并停在 `AWAITINGOWNERAPPROVAL`，新 code 已报告给 owner，
  本轮不执行 approve。owner 批准前，Complete/Confirm、文本会话、断线恢复、
  麦克风和真实远程 STT 均未验收；mock Node 只能作为隔离控制面证据，不能替代
  Hermes 实机证据。
- 本轮发现前台 harness 会随 Codex 会话结束而丢失 owner 私钥；旧 `BLF7-G3SC`
  未被迁移或伪造批准。已重建临时 `agent_talk` schema，并改用 `setsid` 脱离会话
  托管 harness：PID `216869` 的 PPID 为 `1024`，SID/PGID 独立，日志和审批 FIFO
  分别为 `/tmp/agent-talk-live-20260813.log` 与
  `/tmp/agent-talk-live-20260813.fifo`。手机重新导入 CA 后提交的新请求为
  `P2GJ-GGS2`，数据库状态 `pending_owner`、pairing id
  `pairing_b00d093a-1272-4636-acc2-8bb4bae961b4`、scopes `{observe,send}`；
  owner 批准前不执行 approve。
- GitHub 只读调研已记录于 D-015：推荐沿用 Tailscale Android 作为私网底座，
  Android Wireless Debugging/ADB TCP/IP 只用于设备验收，scrcpy 只用于诊断；
  WireGuard Android 仅作为未来自建 VPN 备选，gRPC-Java 作为 Android HTTP/2
  TLS/ALPN 参考。没有找到需要引入 Agent_Talk 的单一“ADB+私网”轮子；当前
  `Tailscale route + exact TLS + app credential` 组合更符合安全边界。
- **2026-08-13 owner approval / pairing evidence（本轮）**：owner 明确批准
  `P2GJ-GGS2`，仅授予 `observe,send`；通过同一 setsid harness 的 FIFO 执行
  approve，未自动批准后续请求。手机 Complete/Confirm 完成后，UI 显示
  `MANUAL LINK PAIRED`、Gateway `https://100.103.253.87`、设备 scope
  `observe / send`；PostgreSQL 只读记录显示 pairing `confirmed`、device 和
  credential `active`。harness PID `216869` 仍由 init 托管并持续 heartbeat。
- **2026-08-13 protocol / credential repair evidence（本轮）**：真实 Gateway
  选择 protocol minor `1`，客户端原先只接受 `0`；已改为接受已声明的 `0..1`，
  `grpc_gateway_live_transport_test.dart` 定向测试通过。实机 access token 过期后
  暴露出客户端未使用已有 `RefreshDeviceCredential` 的缺陷；现已用设备密钥签署
  refresh payload、校验新 credential facts、按 generation 更新 secure storage，
  定向 pairing/store/live 测试 22 项通过。profile APK build number `2002` 显示
  `Connected`，最终 build number `2003` 安装后重连同样显示
  `Authenticated Gateway stream is active`；未放宽 TLS、bearer 或 scope 校验。
- **2026-08-13 text path evidence（本轮）**：Android 创建的会话标题为
  `Live text e e post refresh`，目标明确是 `Agent_Talk isolated mock Agent`。
  手机获取 control lease 后，对无害测试短句执行 Edit → Confirm → Handoff；UI
  显示 `Control held by this device`、`Request completed` 和完整 mock 回复。
  PostgreSQL request 为 `completed`，事件序列 1–4 为 accepted、working、
  message.completed、request.completed；harness 仅有一个 `MOCK_NODE_DISPATCH`。
  这是手机 ↔ 隔离 Gateway ↔ mock Node 的实机证据，不能写成 Hermes 证据。
- **2026-08-13 client reconnect evidence（本轮）**：主动 Disconnect 后手机显示
  `Not connected`，`Uncertain submissions were not resent`；重新 Connect 后
  Gateway stream、历史 mock 回复和 `Request completed` 恢复。发现的已 accepted
  request 状态污染已修复，补充 controller 定向测试 4 项通过；最终 APK
  build number `2003` 实机 UI 不再显示 `uncertain`。该结果覆盖客户端 stream
  断开/重连和事件恢复，不覆盖物理断网、进程重启或 Hermes run 恢复。
- **2026-08-13 remote STT gate（本轮）**：最终 Android 语音设置页仍为
  `STT provider / Disabled`，`Test STT readiness` 不可用；页面提供
  `Consented HTTPS provider (Android)` 选项，但本轮没有真实 provider origin、
  独立 token、retention disclosure 或明确用户 consent。因此没有上传音频，真实
  remote STT、Android microphone permission、中文识别与断网恢复仍为 blocked，
  不使用 fake 或离线测试冒充实机通过。

**2026-08-13 remote STT provider preparation（本轮）**：核对发现项目自带的
`services/stt/voxhandoff-stt` 是 stdio JSONL sidecar，手机客户端的生产远程
适配器则要求 `/v1/health` 与 `/v1/transcribe` HTTPS 契约；两者之间原本没有可
直接启动的网络服务。本轮新增最小 HTTPS adapter，复用现有 faster-whisper
backend/sidecar 语义，默认 loopback、独立 Bearer token、有界请求、TLS 1.2+、
无明文/重定向/模型下载；Android network config 仅在 debug-overrides 信任 user
CA，release/base 仍只信 system roots。服务使用本地
`/home/roco/.cache/faster-whisper-base` warmup 成功，services/stt 共 14 项离线
测试通过；测试证书链及 Tailscale SAN 已验证，Tailscale TCP 443 临时转发至
  `127.0.0.1:18654`，health 实测返回 `ready`。这只是 provider 准备和宿主健康证据。
无 token 的 POST 返回 `401`，带独立 token 的 malformed body 返回 `400`，鉴权 smoke
没有发送音频。
实体 Android 新 profile 包尚未安装，当前停在系统“来自未知来源 / 继续安装”确认
页；因此手机 readiness、真实录音、用户 consent、中文质量和断网恢复仍未关闭，
没有上传音频，也没有把 synthetic/fake 结果写成实机通过。

随后按要求使用 `adb install --no-streaming -r` 重试，发现设备已有更高
`versionCode=2003`；在保留数据的 `-d` 选项下重新安装返回 `Success`，但系统没有
再次显示“来自未知来源/继续安装”弹窗，当前前台仍为 Launcher，`RECORD_AUDIO` 仍为
未授权。因此本阶段只关闭“APK 已安装”这一事实，未关闭“用户确认交互”、provider
配置、readiness、录音、consent、中文识别或断网恢复门；按边界暂停后续操作。

### 0.1.2 2026-08-14 Android PCM 断链修复（第四轮）

- 本轮在 `AndroidAudioCapture.kt` 的原生 readLoop 增加固定 tag
  `VoxHandoffAudio` 诊断：记录 `onListen`、`onCancel`、`start`、`prepare`、
  `beginCapture`、前 20 次 `readCount`，以及前 20 次 push 的成功/跳过状态；只记录
  count/bytes、sink null 和 discarding，不记录 PCM、token、证书或音频内容。
- 核对结果：Kotlin 与 Dart 的 control/event channel 分别都是
  `agent_talk/android_audio_capture` / `agent_talk/android_audio_capture_events`；
  Dart 先订阅 `frames` 再调用 native `start`，`_discarding` 只在 cancel/关闭路径置真。
  Kotlin 现在在 `eventSink` 未就绪时暂存 start result，待 `onListen` 后再启动
  readLoop 并返回成功；2 秒仍无 sink 则返回固定错误，避免静默丢 PCM。
- 本地证据：Dart format 通过；`flutter analyze` 无问题；录音定向测试 2 项通过；
  `:app:compileDebugKotlin` 通过；固定 Flutter 3.44.6 的 `flutter:check` 为 232 项
  通过、2 项预置 live smoke 跳过。默认 PATH 缺少 `flutter`，使用 pinned SDK PATH
  重跑成功。
- Debug APK 已由 Flutter 3.44.6 构建，SHA-256 为
  `81a4c60b0ef4f6fefe1a65e6cf1dba5aee4a12d602567e91980979869b88e858`。
  通过 Tailscale ADB 推送后设备前台出现
  `com.android.packageinstaller/.PackageInterceptActivity`，安装确认未代点，
  `lastUpdateTime` 仍为 `2026-08-14 09:03:29`，所以本 APK 未写成已安装。
- 因安装确认门阻塞，本轮没有启动新 APK、没有重新验证 readiness、没有触发录音，
  没有原生 read/sink、服务端 bytes/rms、转写文本或 UI 成功证据。上一轮服务端
  `422 stt_no_audio` 仍是历史失败事实，不能替代本轮新包证据。
- 本轮追加日志：`/tmp/voxhandoff-acceptance-20260814.log`。Hermes 零改动，未 push。

### 0.1.3 2026-08-14 长录音分块修复与 STT 配置简化（第五/六轮）

- D-035（服务端单帧上限导致长录音空音频）：根因是
  `services/stt/voxhandoff_stt/http_service.py` 的 `HttpSttProvider.transcribe`
  把整个录音编码进单个 push 帧，而 stdio 协议 `MAX_CHUNK_BYTES = 262144`
  限制单块音频；超过约 8 秒（>256KB）的录音被 `decode_chunk` 拒绝，
  `session.audio` 为空，最终 `stt_no_audio`。此前所有手机录音（26 秒约
  832KB、40 秒约 1.28MB）都因此失败，1 秒 curl 测试（32KB）能到
  `stt_empty_transcript`，造成“客户端链路问题”误判。修复：按 262144
  切分音频、sequence 递增 push、最后接 end 帧；curl 32000B/288000B/620800B
  合成 PCM 验证（前两者 `stt_empty_transcript`、620800B 返回 200 与转写文本）。
- D-035 客户端配套：`AndroidAudioRecordChannel.frames` 缓存单一
  `receiveBroadcastStream()` 导致首次录音后第二次全丢；改为每次会话新建流，
  并沿 capture/controller/transport 增加仅记录帧数/字节数的诊断日志。
- D-035 真机证据：实体 `V2359A` 新进程录音约 19 秒，Dart 诊断
  `audioBytes=620800 base64Chars=827736`；服务端 `POST /v1/transcribe 200`；
  UI 显示中文草稿、`Transcript inserted · review and confirm before send`、
  `Discard transcript` 与可用 `Confirm`。录音→远程 STT→可编辑终稿→确认
  链路首次闭环（faster-whisper 对 TTS 测试音频有少量同音错字，属模型识别
  质量，非链路故障）。
- D-036（STT 配置门槛简化）：设置页新增 `Fetch disclosure` 按钮——校验
  HTTPS、token 优先输入值否则读 secure storage、成功自动填充
  TLS/retention/revision/providerId、失败内联显示；声明字段变更自动撤销
  旧 consent。Codex 提交 `f267dbb`（feat: 简化远程 STT 配置门槛）。
  验证：flutter analyze 通过；全量 Flutter 239 通过（2 live smoke 跳过）；
  服务端 unittest 15/15。真机简化配置流程端到端验证待做（无 STT token 且
  服务未监听，未伪造结果）。
- 配套代码维护：Codex 完成结构减负重构（拆分 gateway/node/client 大文件，
  见提交 dcf252d / 3231082 / 26c9c7b）。布洛妮娅验收：`npm run check` 通过、
  `npm test` 168 过 / 0 失败、固定 Flutter 3.44.6 `flutter:check` 239 过 /
  2 live smoke 跳过；已 push 至 GitHub（CI 仅 workflow_dispatch 手动触发，
  未触发）。
- 未关闭（真机验收）：D-036 简化配置端到端、连续 10 轮 GUI、实体麦克风
  全链路、sidecar 产物打包（Linux release 未提供
  `-DVOXHANDOFF_STT_EXECUTABLE`）、release signing（仍 debug signing）、
  Hermes 真实纵向链路（上游能力阻断，非本仓库可解）。

## 0.2 2026-08-11 验收修复（历史维护）

验收报告记录的 VH-ACC-001 已有可复现根因：生产 Node 的 `ConnectNode`
双向流继承了 transport 的 `defaultTimeoutMs: 30_000`。ConnectRPC 的 deadline
覆盖整个 RPC，HTTP/2 ping 和应用 heartbeat 都不会重置它，因此健康连接会在约
30 秒结束；原进程也没有重连监督。

- `ConnectNode` 现在显式传入 `timeoutMs: 0`，保留 transport 的有限默认值给将来
  的短 RPC；
- 进程以有界指数退避重建 Gateway client/stream，只重试可恢复的 transport
  错误，认证和协议错误保持失败；
- Gateway 断开不会中止已接受的 Hermes run，也不会再次提交 `startRun`。事件会等到
  新 stream 完成 handshake 和 Node registration 后再转发；显式 SIGINT/SIGTERM
  才终止运行；
- 协议升级为 1.1：Gateway 只在 Node event 已被 ledger 耐久接受后回传精确
  `NodeEventReceipt`。Connector 以最多 256 帧的进程内 journal 保留未回执事件，
  注册后按序重放，严格匹配回执后才移除；终态 Hermes run 也等待回执，output epoch
  覆盖断流至新 handshake 窗口，避免同一 event 双帧。该 journal 不跨进程崩溃恢复。
  1.0 仅作为滚动升级兼容的 enqueue-only 降级路径，没有 receipt 或无损重连承诺；
- `AGENT_TALK_LOOPBACK_INTEGRATION=1 npm run test:transport` 于本次修复分支通过：
  Gateway 的两项真实 loopback HTTP/2 门通过，Node 生产参数下的真实长流持续
  超过 60,000 ms 后由测试显式取消；另有断流重连、丢失回执重放、断流到新 handshake
  窗口事件不双帧、无重复 `startRun` 与 supervisor 单元回归。

这只关闭 Node/Gateway transport 的本地自动化缺口。真实 PostgreSQL migration/restart、
Hermes 0.20 capability 与 H1、实体 GUI/麦克风、真实 STT/TTS/provider、平台启动、
10 分钟稳定性、备份恢复和发布证据仍须按下方独立证据轴复验，不能因此写为完整项目
发布验收通过。

## 1. 归档时的状态

以下内容是历史归档，不代表当前客户端支持范围。M3–M6 的 Fedora/Linux、Wayland、
benchmark artifacts、Linux release 和 release bundle 记录均保留为真实历史证据；
当前支持范围以本文开头和 0.1 节为准，Linux 不提供客户端。

### 1.1 2026-08-02 权威快照（归档前）

当前产品基线是“统一个人助手”：Hermes 是主要且唯一具有 Agent 语义的工作后端，用户自接 OpenAI-compatible API 是纯聊天/陪伴后端。M0–M4 的历史交付不回退；M5 批次 1–5 的本地实现基座已完成（Provider/凭据/历史隔离、确认目标绑定、request lifecycle、消息终态、AssistantProfile、conversation context、语音配置与播报策略），阶段未关闭，剩余门集中在真实语音与实体设备证据（连续 10 轮 GUI、至少一轮实体麦克风全链路、正式 STT sidecar bundle、remote STT 契约）；批次 6 正在收口 PR #4 事实、review map 与证据登记。H1 独立受 Hermes 上游能力阻断，不是 M5 完成条件。

阶段编号表示历史工作包，不表示严格线性顺序；M6 的界面/性能工作曾提前完成。当前映射如下：

| 阶段 | 原始目标 | 当前状态 | 已完成证据 | 剩余验收/发布阻断 | 外部依赖 |
| --- | --- | --- | --- | --- | --- |
| M-1 | 基线、安全和交付治理 | 完成 | `spec/`、repository check、威胁模型、Git 基线 | 无重新开启项 | 无 |
| M0 | Agent 协议核心与隔离 PoC | 历史完成 | Core taxonomy/property tests；Codex/Hermes 直接 PoC 的多轮、stop、approval、断线与恢复 | 只作协议回归，不代表当前生产 Hermes | 隔离 Agent 版本 |
| M1 | Protobuf/Gateway/PostgreSQL 耐久控制面 | 完成 | 真实 PostgreSQL、HTTP/2、重连/重复/乱序/Gateway 重建收敛 | 发行备份恢复仍属总发布门 | PostgreSQL 运行环境 |
| M2 | Flutter 文字客户端与多设备同步 | 完成 | Drift/cursor、配对、lease、审批、两设备恢复、五平台 CI | 实体安装/签名/非 Linux keyring 属总发布门 | 五端发行环境 |
| M3 | 可确认、可打断的语音闭环 | 工程完成；推荐语音 profile 未达标 | 录音/STT/TTS failure isolation、125 项当时测试、真实服务合成链；CPU/base 明确 `text-first degraded` | 推荐设备真人语料、≥95%、10 次 cold start | 合格 STT/TTS 与设备 |
| M4 | SignalCore、桌面能力与 60/120 Hz 表现 | 完成 | Fedora 60 Hz；vivo X100s 120 Hz hot profile；Wayland 明确降级 | cold-start 观察与发行设备矩阵不改写阶段结论 | 实体平台环境 |
| M5 | GUI Direct LLM + 可配置语音聊天 | **批次 1–5 的本地实现切片已完成，阶段未关闭** | Direct request ownership/终态/bounded I/O、AssistantProfile/capability projection、conversation context/记忆/摘要、voice binding、GPT-SoVITS/Piper 配置入口、播报策略、固定 Flutter 209 tests、Node/STT 全量门与 Linux release | remote STT production wiring、正式 sidecar 产物、连续 10 轮 GUI、实体麦克风完整 GUI、发布前复验 | 用户配置的 LLM/STT/TTS/麦克风；remote provider 与 release sidecar |
| H1 | 真实 Flutter→Gateway/PostgreSQL→Connector→Hermes 纵向链路 | **外部阻断** | Connector/Gateway fake 边界；直接 Hermes 0.19 PoC；fail-closed 门 | 真实 10 轮、stop、断线/重启、approval 纵向门 | 首先需要幂等 run submission；完整 H1 还需不可变 approval 身份/精确 resolution |
| M6 | Hermes 会话 UI、长历史与真实负载 | UI/Fedora 门完成 | 轮次聚合、2,000 事件、Fedora 60 Hz P95 | 新 HomeScreen 的实体移动 120 Hz profile | 实体高刷手机 |

### 1.2 证据轴与 PR #4

证据按独立轴记录，不能串联推导：

1. 源码/adapter 存在；
2. 本地自动化与质量门；
3. 远端 CI；
4. 真实数据库或真实服务 adapter；
5. 人工 GUI/实体设备完整路径；
6. 发布汇总门。

CI 只能证明其 runner 上声明的自动化，不能证明实体麦克风、真实第三方服务或人工交互；真实 service smoke 也不能证明 production GUI。发布门是适用证据轴在同一候选版本上的汇总结论，不是一个能反向替代其他证据的“最高层”。

PR [#4](https://github.com/Dreamy-MoLing/VoxHandoff/pull/4) 当前为 Open、Draft、mergeable，base `main@f4f42e6`，head 为 `agent/m4-fairy-desktop@3f3a3c0`（功能实现 head 为其前一提交 `ca6b794`，随后仅有 docs-only 提交）；它是覆盖 M2/M3/M4、Hermes/H1/M6 与 M5 的累计 PR，不是 M5-only。随后追加的本文件刷新属于 docs-only 交付记录，不改变上述功能基线。

针对当前 head `3f3a3c0` 的 [GitHub Actions run 30706647988](https://github.com/Dreamy-MoLing/VoxHandoff/actions/runs/30706647988) 与 [run 30706647923](https://github.com/Dreamy-MoLing/VoxHandoff/actions/runs/30706647923) 均已 `completed/success`，各自 5 个 job（Node quality、Flutter Linux quality、Android、Apple、Windows platform build）全部 success；CI 的本地门与四端构建可写为远端全绿，但不替代实体麦克风、真实服务或人工 GUI 验收。较早 [run 30643640922](https://github.com/Dreamy-MoLing/VoxHandoff/actions/runs/30643640922) 的 runner 分配前 billing/spending failure 与 [run 30706592439](https://github.com/Dreamy-MoLing/VoxHandoff/actions/runs/30706592439)/[30706591806](https://github.com/Dreamy-MoLing/VoxHandoff/actions/runs/30706591806) 的中间 `in_progress` 均为历史记录，**不再是当前 CI 阻断或结论**。

PR 正文已同步本轮批次 1–5 实现与剩余证据（批次 6 起由 Hermes 侧按 review map 统一刷新）。核验结论是：实体麦克风与连续 GUI 仍是 M5 门；H1 是独立上游阻断，不是 M5/CI 失败；“security workbench” 不能在没有正式需求和验收定义时充当阶段门；billing 说明已经过时。当前合理的 Draft 理由是批次 6 收口、连续 GUI/实体麦克风验收和累计 PR 审查。

### 1.3 本轮已确认的实现差异

| # | 仓库事实 | 工程结论 | 进入批次 |
| --- | --- | --- | --- |
| 1 | **批次 1 前** Direct LLM 只有固定 `default-direct-llm` 配置；改 origin/model 复用 ID，空 key 保留旧 key；历史按该 ID 加载并全部发送 | 已由批次 1 的 Profile/credential/configuration/conversation revision 与 legacy 隔离关闭 | 批次 1（已关闭） |
| 2 | **批次 1 前** `confirmDraft()` 只冻结文本；发送时才读取当前 ChatSource/Profile/Hermes conversation/route | 已由批次 1 的 immutable `ConfirmedDraft` 与 exact target/context 校验关闭 | 批次 1（已关闭） |
| 3 | source/profile/config 切换不取消旧流；test/chat 共用单一 `_active`；隐藏 Direct 页面仍可写历史和触发 TTS | 本轮已按 request ID + configuration owner 隔离聊天与测试句柄；切换先取消、写入 cancelled barrier，迟到 delta/TTS 丢弃 | 批次 2（本轮实现） |
| 4 | **批次 1 前** Direct message 只有 `completed: bool`；提前 EOF 会走成功/TTS 路径，cancel/failure/超限 partial 虽当次不播报却仍以 completed 持久化并进入后续全历史 payload | 本轮 runtime 映射为 `completed/cancelled/failed/incomplete/truncated`，完成必须有 `[DONE]`；context builder 另行排除非 completed/native 内容 | 批次 2、4（本轮实现） |
| 5 | 正常 SSE 已在 UTF-8/分行前限制 4 MiB；`GET /models` 与非 2xx body 仍直接无界 `drain()` | 本轮统一 request/response byte limit 与 timeout，request 也有 1 MiB 上限；已补充真实 loopback 非 2xx/超大 body fixture，执行证据见批次 2 补证记录 | 批次 2（本轮实现/补证） |
| 6 | 每个 delta 同步写 SQLite，每轮发送全部历史；没有 conversation ID、上下文预算、固定记忆、滚动摘要或删除 API | 本轮以 conversation 隔离的 Drift memory/summary、48 KiB UTF-8 budget + 8 KiB reserve、确定性本地 summary rebuild 和 CRUD 关闭最小上下文边界；可调 policy/LLM 自动摘要另拆产品决策 | 批次 4（本轮实现） |
| 7 | Hermes 与 Direct 使用独立页面/state；没有 AssistantProfile 或共享人格/记忆模型 | 本轮建立共享 AssistantProfile、voice assistant binding 和 common composer/banner 语义；内容视图仍按真实 backend capability 分开，Direct 不出现 Agent 控件 | 批次 3（本轮实现） |
| 8 | GPT-SoVITS adapter 已有但无完整设置入口；Piper adapter/config 有 speaker 字段但 UI/测试/`/info` capability 未覆盖；远程 STT 只有隔离 adapter；bundled STT launcher 只找 `libexec/voxhandoff-stt`，当前构建未打包它且默认模型可能触发下载；无麦克风选择，STT language 未接生产，播报/打断策略不可配置 | 本轮补齐了 GPT-SoVITS origin/reference/language 入口、播报策略的持久化/UI/自动与手动行为，以及此前的本地 STT language/model path、麦克风枚举/选择降级、Piper speaker/capability/语速换算和 voice assistant binding；remote STT、可执行 sidecar 产物和真实 GUI 证据仍未关闭 | 批次 5（本轮实现） |
| 9 | PR #4 仍为累计 Draft；功能 head 的 CI 在本快照时仍运行中，H1 首先被 `idempotency=false` 阻断 | billing 不再是 blocker；M5 与 H1 必须分开关闭，远端运行完成前不宣称 CI 全绿 | 批次 6、7 |

同时确认的正向安全事实：Gateway 从持久化 `(nodeId, agentId, capabilityRevision, sessionId)` route 接受、恢复、claim 和校验 Node event；非空 Hermes session 在同一 `(nodeId, agentId, capabilityRevision)` 下只能绑定一个 conversation；Hermes 0.19 resolution 是无 immutable approval ID 的 FIFO，Connector 以 `hermes_approval_resolution_ambiguous` fail closed；Connector session store 合并冷启动加载和同 conversation 并发创建。`uncertain`、禁止静默重提、approval/CAS、control lease、完整回复与语音失败隔离继续是不可回退基线。

### 1.4 历史环境与详细证据登记

基线日期环境：Fedora 44、Node.js 22.22.2、npm 10.9.7、Python 3.14.6、uv 0.11.26、Codex CLI 0.144.6、Hermes Agent 0.19.0、ffmpeg 8.1.2；项目内 Buf CLI 1.72.0、Protobuf-ES 2.12.1、node-postgres 8.22.0 和本地 Dart `protoc_plugin` 25.0.0。PostgreSQL 集成基线为 17 Alpine、manifest digest `sha256:af194ccf3e2d7fe367012c7b88ce8b816c5c889b18a5b316799a1f0d7eac746a`。M2 使用官方 stable Flutter 3.44.6 / Dart 3.12.2 用户级 SDK，Linux archive SHA-256 固定于 `toolchains/flutter.json`；Fedora 主机已安装 Clang 22.1.8、GTK 3 与 libsecret development headers，Linux release build 和 Secret Service 真读写/删除通过。M4 真机门使用 Android command-line tools、Platform Tools 37.0.0、Build Tools/API 36、NDK 28.2.13676358 与 OpenJDK 25，并已通过 `flutter doctor -v` 的 Android toolchain 和 license 检查。

2026-07-31 的阶段描述是：M4 及原 M6 的界面/性能工作已完成，M5 转为“可用语音聊天打通”，Hermes 生产纵向门改列 H1。该历史描述已由上方 2026-08-01 快照校准；既有 Codex 适配器和证据只保留为历史回归。任何新里程碑都不得回退完整文字、审批、lease、cursor、`uncertain`、防重提或语音失败隔离语义。

2026-07-29 的实现状态记录：

- Hermes capability 已改为 fail closed；Hermes 0.19 的显式 feature/endpoint 已逐项映射，数字 Unix timestamp 被规范化为 UTC，事件 ID 可跨 client recreation 确定性重建，原生 SSE 恢复锚点进入 `Last-Event-ID`，本地补充事件与原生 sequence 保持单调且不冲突；
- `services/node` 已实现生产 Connector：从环境变量读取 Gateway/Hermes 配置和 token，持久化不含正文/秘密的 conversation→session 映射，接通注册、会话创建/恢复、文字 run、SSE、stop、approval 与明确错误；生产边界的真实 Gateway stream + fake Hermes 集成测试覆盖 dispatch、事件和交互往返；
- Flutter timeline 已按 request 聚合为轮次、Hermes 回复、工具轨迹、未决交互和终态；长列表使用惰性构建，高频音量只更新隔离子树，PCM 包络移至 isolate，活动请求只取非终态轮次；
- SignalCore 已扩大为状态主体并按状态改变几何、轨道、能量和音频响应；idle/completed/failed 与 reduced-motion 不持有持续 ticker，着色器已通过 Flutter runtime-effect 离线编译；
- 新增长历史 HomeScreen widget gate（桌面 500、手机 2,000 条）和实际 HomeScreen 的并发 delta/录音/TTS/shader profile 探针。

这些条目表示实现与已列出的证据，不表示真实 Hermes MVP 已全部验收。2026-07-29 在独立 `/tmp` HERMES_HOME、字面量 loopback 18642、无消息平台凭据且不接触默认 gateway 的 Hermes 0.19.0 环境中，直接 adapter PoC 已完成同一 session 10/10 轮、stop、manual approval 明确拒绝、运行中 SIGKILL→`uncertain`，以及 gateway 重启后的旧 session 恢复。该版本未广告 idempotency、event replay 或 sequence recovery 字段，adapter 对缺失能力 fail closed，协商结果为 `idempotency=false`、`replay=false`、`sequenceRecovery=false`；当前 `/v1/runs` 也没有可验证的幂等提交实现，因此生产 Connector 按安全契约拒绝注册，真实 Flutter→Gateway/PostgreSQL→Connector→Hermes 纵向门仍未关闭。该门不能用 fake Hermes、直接 adapter PoC 或放宽 `uncertain` 防重提替代。

固定 Flutter 3.44.6 / Dart 3.12.2 的 analyze、170 项 test（含 widget/golden/accessibility/长历史）、runtime-effect 编译和 Linux x64 release build 已通过。真实 release HomeScreen 在 60.001 Hz Fedora/Wayland 上以 2,000 条耐久事件测得 stress total P50/P95 8,687/12,759 µs、idle 6,056/12,964 µs，均通过 16,667 µs P95 门；完整环境、原始测量和汇总位于 `artifacts/benchmarks/mvp-fedora44-20260729/`。这不替代 120 Hz 实体手机的 MVP HomeScreen profile。

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
- CI 新增固定 Flutter 3.44.6 的 Linux analyze/test/release/Secret Service 门，以及 Android debug APK、macOS release、iOS simulator 和 Windows release 构建矩阵；根 `npm run check` 已按 workspace 依赖拓扑在 protocol `--noEmit` 校验后显式生成 `dist`，以移除 `origin/main` 干净 runner 在 Gateway 检查时找不到 `@agent-talk/protocol` 的顺序缺陷；Dart 生成一致性门则在固定 Flutter SDK 就绪后运行。这些是共享 M2 客户端的合并门，不替代后续签名、安装、升级、卸载与实体设备发行验收；
- Dart protocol 依赖经真实 pub solver 将 `protobuf` 修正为与 `grpc 5.1.0` 相容的 6.x，不使用 dependency override；客户端运行依赖已固定 `drift 2.34.2`、`path_provider 2.1.6` 和传递依赖 `sqlite3 3.5.0`，开发生成器固定 `drift_dev 2.34.0` / `build_runner 2.15.1`。PowerSync 未进入依赖，仅保留通过独立许可、运维、最小授权和量化收益 gate 后的可选 adapter；
- M4 信号生命核心以纯 Dart selector 从规范 Agent event、本地 voice/speech 和精确 identity 生成 11 个互斥主状态，固定 approval/clarification → uncertain → failed → voice → work → speech → completed → idle 优先级；GLSL 与静态 CustomPainter 共用状态几何，录音使用当前 capture level，播放使用当前 segment 的 PCM16 WAV RMS 包络，shader load failure、系统减少动态和 60/120 Hz profile 都不改变语义。桌面固定安全区、手机可滚动槽位、2 倍系统字号、审批/uncertain 高对比和桌面/手机 golden 已进入 Flutter 门；
- M4 桌面能力由独立 port/controller/production adapter 组合 `hotkey_manager`、`tray_manager`、`local_notifier` 与 `window_manager`。启动 replay 不弹历史通知，新事件按 conversation sequence 高水位去重且通知只含固定阶段文案；全局/应用内快捷键只切换语音草稿。close-to-tray 只有托盘成功后启用，Fedora 44 niri/Wayland 真自检明确得到 hotkey/tray `degraded`、notifications/window `available`，没有伪装 X11 能力；
- 仓库级威胁模型：关键资产、攻击者、九条信任边界、重点攻击故事和严重度校准；
- repository consistency check 和最小权限 GitHub CI：locked install、check、offline tests。

截至 2026-07-31 尚未完成或未实测的发布项：

- Hermes 0.19.0 尚未提供生产 Connector 所需的显式幂等 run submission；在该能力补齐前，真实 Flutter/Gateway/PostgreSQL/Connector 端到端 10 轮与重启门保持阻断；
- 120 Hz 实体手机上的新 HomeScreen 2,000 条历史、并发 delta/录音/TTS/SignalCore profile；
- 具名真人麦克风语料、10 次冷启动，以及达到推荐延迟/成功率的加速 TTS + 更强中文 STT release profile；当前 Fedora CPU/base profile 已实测并明确降级，不允许默认自动播报；
- 实体手机/桌面的远程网络、非 Linux keyring 真读写、签名打包、安装/升级/卸载与发布测试；这些发行工作当前暂停，不得从 CI 编译结果推断通过。

Hermes 默认 gateway 当前由 user systemd service 运行并关联 QQBot；它不是 VoxHandoff 测试资源。Live PoC 必须使用不同 HERMES_HOME、端口、PID/state 目录和只含所需 provider key 的干净子进程环境，不得停止、重启或复用默认 gateway。

## 2. 仓库布局

```text
apps/
  poc-cli/              # 可重复协议/故障 PoC
  client/               # Flutter 客户端共享 shell、领域/application 层与平台 runner
packages/
  core/                 # 无外部依赖的领域模型和状态机
  adapters/             # Hermes 正式适配器；Codex 历史回归隔离保留
  protocol/             # Protobuf/Buf schema、TS/Dart binding 与协商测试
  sidecar/              # desktop stdio host（后续统一打包 supervisor）
services/
  gateway/              # 耐久控制面、gRPC/HTTPS、配对、凭据与 PostgreSQL adapter
  node/                 # Hermes 主机 Connector、配置与 session state
  stt/                  # Python streaming STT sidecar、uv lock 与离线协议测试
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
- 依赖只有在明显改善正确性、支持客户端平台覆盖或维护成本时加入；
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
| Flutter `record` | 7.1.1，Flutter lockfile | BSD-3-Clause | [官方平台矩阵](https://pub.dev/packages/record)覆盖 Android/iOS/Linux/macOS/Windows；只使用内存 PCM16 stream、权限/encoder runtime probe，并提供 `VOXHANDOFF_AUDIO_CAPTURE_SELF_TEST=1`；Linux 还要求 `parecord/pactl`，CI 已安装 `pulseaudio-utils` | `AudioCapturePort` 隔离插件；单平台可替换原生 capture 而不改变 STT/确认状态机 |
| `media_kit` / `media_kit_libs_audio` | 1.2.6 / 1.0.7，Flutter lockfile | MIT / MIT | [官方仓库](https://github.com/media-kit/media-kit)覆盖五目标平台；adapter 只接收有界内存音频并暴露 play/stop，队列和 stale identity 留在 application 层 | `AudioPlaybackPort` 隔离播放器；可换平台播放器而不改变 segment identity/TTS 队列 |
| `hotkey_manager` / `tray_manager` / `window_manager` / `local_notifier` | 0.2.3 / 0.5.3 / 0.5.2 / 0.1.6，Flutter lockfile | MIT | pub.dev 声明 Windows/macOS/Linux；application 只依赖 `DesktopIntegrationPort`，Linux 离线 MethodChannel 测试和 Fedora 44 release 自检覆盖逐项降级。Linux build 固定 `keybinder-3.0`、Ayatana AppIndicator 与 `libnotify` 开发包；Wayland 不调用 X11 Keybinder | 可逐平台替换 portal/native adapter，不改变 controller/通知 enum；托盘或热键失败保留前台窗口、应用内快捷键和完整正文 |
| `faster-whisper` | 1.2.1，`services/stt/uv.lock` | MIT | [SYSTRAN 官方仓库](https://github.com/SYSTRAN/faster-whisper)；Python 3.11 本机 base 模型已通过 JSONL sidecar、临时文件权限/清理和真实中文音频链路 | `SttBackend` 与 1.0 sidecar protocol 隔离引擎；30 条中文门不达标时换模型/后端而不改变 Flutter domain |
| PyInstaller / hooks-contrib / altgraph | 6.21.0 / 2026.6 / 0.17.5，`services/stt/packaging/requirements-build.txt` | GPLv2-or-later（PyInstaller 分发例外）/ Apache-2.0 或 GPL / MIT | [PyInstaller 官方手册](https://pyinstaller.org/en/stable/)支持 Linux 原生 one-file；只在匹配 Linux 主机/架构构建，模型不进 executable | 仅替换 packaging layer；sidecar JSONL 与 `SttBackend` 不变，必要时可切换 Nuitka 或平台原生 bundle |
| GPT-SoVITS | 本机 `api_v2.py` `/tts` 契约；不纳入应用依赖 | MIT（发布时连同模型/权重另审） | [官方仓库](https://github.com/RVC-Boss/GPT-SoVITS)契约已真合成 WAV；Client 仅允许 loopback HTTP build config | `TtsPort` 隔离 HTTP 服务和音色；可换其他本地/经同意的远程 TTS，不改变完整回复或播报摘要 |
| `pg` / `@types/pg` | 8.22.0 / 8.20.0，npm lockfile | MIT | node-postgres 长期维护；使用底层 Pool/transaction API，不引入 ORM | `GatewayLedger` 隔离 SQL；可替换其他 PostgreSQL driver 而不改变 acceptance 语义 |
| PostgreSQL test image | 17 Alpine，固定 manifest digest | PostgreSQL License；镜像含各组件许可证 | 官方镜像；本地隔离测试和 CI 使用同一 digest | 生产部署独立；测试可换受支持 PostgreSQL 版本并先跑 migration/fixture gate |
| `@connectrpc/connect` / `@connectrpc/connect-node` | 2.1.2，npm lockfile | Apache-2.0 | Buf/CNCF Connect 官方 TypeScript 实现；支持 Node、gRPC 与 streaming，真实 HTTP/2 测试通过 | service 只依赖生成的标准 Protobuf descriptor；可换 `grpc-js` 而不改变 wire schema/账本 |

TypeScript 与 Dart binding 都使用仓库固定的本地 Buf plugin；依赖已锁定后不把私有 proto 上传到远程 generator。普通 `npm run check` 校验已提交 TypeScript 生成物并先 emit protocol `dist` 再检查消费者；CI 与显式 `protocol:check:dart` 使用固定 Flutter SDK 内嵌 Dart 重新生成并逐字比较。`npm run flutter:check` 已真编译 protocol package 并分析、测试共享客户端；在各目标平台 toolchain 和 runner build 实际通过前，仍不得把它表述为所有目标平台编译成功。

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

完成证据：Gateway directory/conversation 的追加协议、expand-first PostgreSQL migration、并发幂等创建和生产 Flutter workspace 已接通；两个独立 Client 账本/router 对共同事件、显式接管、断线与 cursor 续播收敛且没有生成 Send；完整回复、工具/审批/澄清/终态、签名审批、lease 定时续租和 uncertain 不重提均有离线门。固定 PostgreSQL 17 的 migration/并发/恢复门与真实 HTTP/2 TLS loopback 已在 Fedora 44 复验；Linux release 与 Secret Service 写/读/删真链路通过。[GitHub Actions run 29899751800](https://github.com/Dreamy-MoLing/VoxHandoff/actions/runs/29899751800) 进一步通过 Node/PostgreSQL、Linux quality/keyring、Android、macOS/iOS 与 Windows 全部门；实体设备与签名发行仍按后续发行门单独验收。

### M3 — 语音闭环（完成：2026-07-22）

目标：实现虚拟主播式可打断分轮对话。

- `record` AudioCapture adapter 和本地权限流程；
- Python streaming STT sidecar + remote STT adapter；
- final transcript 默认确认；
- GPT-SoVITS warmup、segment queue、`media_kit` 播放和 300 ms stop；
- 完整回复/播报/音频三个失败域；
- 30 条中文技术 STT、30 条 TTS、50 次端到端基准。

退出条件：达到 `PRODUCT.md` 延迟/成功率目标，或以实测经评审修订指标；语音失败不损伤文字链路。

完成证据：Flutter 领域/application 层已把录音、STT、终稿确认、短播报、TTS、播放和本地存储拆成独立 failure stage；`record 7.1.1` 只输出内存 PCM，终稿进入现有可编辑草稿而不自动确认/发送，原文由独立 Drift 库保留 7 天。Python 1.0 JSONL sidecar 固定 frame/chunk/duration/sequence，临时 WAV 为 `0600` 并在 final/cancel/启动清理；远程 STT 默认无生产 provider，只有 origin/TLS/retention/streaming/revision 与用户同意完全一致才可构造上传 adapter。完整 `message.completed` 只在 `request.completed` 后进入确定性脱敏摘要，segment identity 绑定 conversation/request/revision/index，播放 N 时预生成 N+1；录音开始只调用 `speech.stop`，不生成 Agent interrupt。

离线门通过 Python sidecar 8 项测试和 Flutter 125 项完整测试；覆盖 final 推理期间取消并立即解除私有 WAV 链接、stdio `end` 后取消、权限拒绝、STT/存储失败、确认隔离、乱序 provisional 拒绝、远程 provider 事实变化重同意与禁止重定向、TTS 请求取消、分段预取、stale stop、Drift 关闭重开/清理、桌面/手机 golden 与 accessibility。最终审查后生成一致性和静态分析无问题，Linux release 再次带 `record`/`media_kit` 原生插件构建成功；默认 PipeWire source 另以 `pw-record` 真采集 2 秒 16 kHz mono PCM（64,000 bytes，mean -24.4 dB/max -5.7 dB）后立即删除。release 内置的 `VOXHANDOFF_AUDIO_CAPTURE_SELF_TEST=1` 正确暴露宿主缺少 `parecord/pactl`，本轮 `pkexec` 未获管理员授权，故 record plugin 的 Fedora 真采集仍作为明确环境门，不得写成已通过；CI 已安装 `pulseaudio-utils`。本机 GPT-SoVITS WAV → PCM → sidecar 真链路返回中文终稿，证明进程和格式契约。[GitHub Actions run 30175530966](https://github.com/Dreamy-MoLing/VoxHandoff/actions/runs/30175530966) 进一步通过 Node/PostgreSQL、Linux quality/release/Secret Service、Android、macOS/iOS 与 Windows 全部门。

脱敏基准位于 `artifacts/benchmarks/m3-fedora44-20260722/`：5 次 warmup 后 30 条合成中文技术语料的 faster-whisper base 非空 final 为 27/30，成功样本 P50 500.04 ms/P95 1953.18 ms，平均 CER 0.678；GPT-SoVITS 30/30 返回 WAV，但 CPU P50 3723.92 ms/P95 5428.33 ms；50 次 STT→确定性回复→TTS 为 44/50（88%）。失败全部保留在分母，因此该 Intel i5-1155G7 CPU/base profile 被拒绝自动语音并按 `PRODUCT.md` 标为 `text-first degraded`，不下调推荐目标。M3 接受的是可替换实现、失败隔离和经评审的降级口径；后续启用推荐 voice release profile 前仍须以更强中文模型/加速 TTS 通过 ≥95%、10 次 cold start 和具名真人设备语料。

### M4 — Fairy 动效与桌面能力（完成：2026-07-25）

目标：在已经可靠的交互上增加原创角色表现。

- GLSL 核心、音频波纹、扫描线和短故障转场；
- Rive 只在受审资产能减少实现复杂度时作为辅助微动效；本阶段没有合适 `.riv` 资产，按架构最小依赖门保留 Flutter 内建 transition 而不引入空 runtime；
- 桌面常驻视觉安全区、录音展开和手机标题/阅读/录音三种尺寸槽位；
- idle/recording/transcribing/awaiting-confirmation/submitting/working/speaking/approval/completed/failed/uncertain 视觉状态；
- 真实麦克风音量、规范 Agent 事件和当前 TTS segment 驱动，stale identity 不继续响应；
- Windows/macOS/Linux 快捷键、托盘、通知和窗口行为；
- 减少动态效果、静态回退、60/120 FPS profile。

退出条件：shader/Rive 故障不影响使用；五端同状态语义一致；核心不覆盖正文、转写或操作；审批和澄清保持高对比度并取得视觉优先级；`uncertain` 不产生完成反馈；减少动态效果下所有状态可由静态几何和文字区分。

实现证据：`SignalCoreSnapshot` selector 的离线矩阵覆盖 11 个状态、安全优先级、已解决交互、uncertain 不完成、stale recording/playback/failure identity；`MediaKitAudioPlayback` 从当前实际 PCM16 WAV 每 50 ms 提取有界 RMS 包络，unsupported、malformed 或超过 4 MiB/2 分钟分析上限的音频返回空而不编造音量，播放超时会停止 native player，application generation/segment identity 在停止或切换时撤销旧 level。原创 GLSL 与静态 painter 始终并存，shader 人工失败、一次性故障转场和 `disableAnimations` widget gate 保留同一语义与几何。桌面正文为固定右侧核心保留安全区，手机标题/阅读/录音状态进入可滚动单列；桌面/390px recording 与 uncertain golden、2 倍系统字号 approval 测试均无溢出。refresh rate 小于 100 Hz 使用 balanced60 detail，100 Hz 以上使用 highRefresh120 detail，Flutter ticker 仍服从实际 display vsync。

桌面 adapter 的 Linux MethodChannel 测试覆盖 Wayland 明确降级、通知无正文/摘要 hash、托盘失败不拦截关闭、初始化竞态、无选择时不跨 conversation 通知，以及 router `replay/live` 来源和 events hydration 双边界后的 replay 去重；历史 replay 也不会重新触发 TTS。Fedora 44 / Clang 22.1.8 release 带四个原生插件构建成功。由于主机 Polkit 本轮没有交互代理，`libnotify-devel` 仅从 Fedora 官方仓库下载到 `/tmp` 提供头文件与链接名，运行时仍链接主机正式 `libnotify.so.4`；真实 Wayland self-test 报告 `hotkey=degraded tray=degraded notifications=available window=available` 并按产品降级契约通过。首轮远端门在 Linux release 通过后暴露 Xvfb 没有系统托盘宿主却被启动探针误判失败；修复只在显式 headless self-test 中接受 hotkey/tray 的可见降级，通知和窗口能力仍须可用，并增加纯策略回归测试。[GitHub Actions run 30182065598](https://github.com/Dreamy-MoLing/VoxHandoff/actions/runs/30182065598) 在 Android profile 触发与前缀日志汇总增量后通过 Node/PostgreSQL、Linux 160 项 Flutter 测试与 analyze/release/Xvfb desktop/Secret Service、Android、macOS/iOS 和 Windows 全部门。

桌面性能证据位于 `artifacts/benchmarks/m4-fedora44-20260725/`：Fedora 44 / Linux 7.1.4、i5-1155G7、Iris Xe、15 GiB RAM、niri/Wayland、power-saver、1920×1080@60.001 Hz 的 Linux release，在 5 帧 shader warmup 后对 11 个状态各采 5 帧；55/55 均低于 16,667 µs，total P50 3,570 µs、P95 7,287 µs。

Android `highRefresh120` 证据位于 `artifacts/benchmarks/m4-android-vivo-x100s-20260725/`：vivo X100s / Android 16 API 36 / MediaTek MT6989 / Mali-G720-Immortalis MC12 / 15,691,500 KiB RAM / 1260×2800@120.000 Hz，低电量模式关闭且测试前后 thermal status 均为 0。刚安装 profile APK 后的首轮 cold 测量有 2/55 帧超过严格的 8,333 µs `FrameTiming.totalSpan` 门，原始结果按失败保留；随后两次不重装 APK 的独立 hot 进程重启均为 0/55 超预算，首轮 total P50/P95 1,044/2,029 µs，复验为 968/2,084 µs。结合 Fedora `balanced60`，M4 的持续渲染 60/120 Hz 门已覆盖；cold 结果只作为后续发行启动性能的明确观察，不得表述为 cold-start 通过。

Android profile 仍以 `--dart-define=VOXHANDOFF_M4_RENDER_BENCHMARK=true` 编译触发同一探针。探针改用 Flutter 同步日志输出，避免 Android 在紧接 `exit()` 时丢失 `stdout.writeln` 缓冲；汇总脚本继续安全剥离 `flutter run`/logcat 前缀。Flutter 3.44.6 的有效 Android 下限为 API 24，Gradle 配置现跟随锁定 SDK 的 `flutter.minSdkVersion`，不再在每次构建时把过时的显式 API 23 静默迁移。真机 profile、具名 exact 环境、脱敏原始测量、严格失败与两次重复通过结果均已入库，未以 emulator、debug build 或 CI APK build 替代。

[GitHub Actions run 30184413298](https://github.com/Dreamy-MoLing/VoxHandoff/actions/runs/30184413298) 已在包含上述真机探针修正和全部 Android 证据的 head 上通过 Node/PostgreSQL、Linux 160 项 Flutter 测试与 analyze/release/Xvfb desktop/Secret Service、Android debug APK、macOS/iOS 和 Windows 全部门。该 CI 证明代码、生成物与五平台构建门一致，但不替代已单独保存的实体 Android profile 结果。

### M5 — GUI 语音聊天打通（实现基座完成；正确性与 GUI 发布门未关闭）

目标：先把已有录音、可编辑文本、聊天 UI、播放与 SignalCore 串成用户可用的语音聊天体感，不等待 Hermes 上游补齐幂等能力。

- 建立来源选择与设置页基座：Hermes、Direct LLM、本地 faster-whisper 与 Piper 可分别显示/测试；完整 Provider Profile、远程 STT、GPT-SoVITS 和策略配置仍以后续批次为准；
- 实现本机直接的 OpenAI-compatible LLM chat adapter，API key 仅由 OS 安全存储持有，支持流式文本、取消与本机历史；
- 将语音控制器接入真实聊天 UI：录音 → 可编辑终稿 → 明确发送 → 流式回复基座 → 可停止的 TTS；无 STT/TTS 或任何一端失败时保留文字聊天；Direct 完整终态缺口见 1.3 #4；
- 将 faster-whisper 与 Piper-compatible 服务作为免费开源默认预设，只提供版本化接口探测、配置引导和连接测试，不捆绑模型、音色、云账号或自动下载；
- 完成一个用户自配 LLM API 的手工 smoke：文字、录音转写（若已配置）、流式回复、播放（若已配置）、取消和断网错误均可见且无 secret 日志；
- 审批、工具执行、跨设备控制和 Hermes `uncertain` 只在 Hermes 路线出现，纯 LLM UI 不得伪装这些状态。

退出条件：在 Fedora 的本机用户配置中，能完成至少 10 轮文本聊天；已配置音频端口时能完成“录音—编辑—发送—回复—播放”一轮；取消和任一配置失败不丢失已确认文本或完整回复，且相关离线/Flutter 测试通过。

当前判断：实现、离线自动化、真实服务 adapter smoke 和最新远端 CI 均已有证据，但 M5 尚未满足退出条件。OpenRouter 10/10 是十个互不共享历史的 transport request，不是连续 GUI conversation；Piper→faster-whisper 使用合成音频，不是 production `record` plugin 的实体麦克风 GUI。关闭 M5 前还必须完成 1.3 中的 Direct LLM 正确性修复、连续十轮 GUI 文本路径，以及“实体麦克风录音 → 编辑 → 目标确认 → 流式回复 → 有声播放/停止”人工验收。Hermes H1 不属于 M5 完成条件。

#### 2026-07-31 Direct LLM 增量证据

本次实现了可独立审查的 direct LLM 最小路径，且不触碰 Hermes/Gateway
的 acceptance、lease、approval、cursor 或 `uncertain` 语义：

- Client 可在 Hermes Gateway 与 Direct LLM 来源之间显式切换。Direct LLM
  使用独立视图，明确标注它没有 Agent host、tool、approval、lease 或跨设备
  command 语义；UI 预期语义是停止只取消当前本机 HTTP stream、绝不伪装 Hermes interrupt，但现有共享 `_active` 的 owner 竞争仍须由批次 2 修复。
- Direct LLM 接受精确 HTTPS API base（空路径或最多四段受限安全 path segment），因此
  可保留 OpenRouter 的 `https://openrouter.ai/api/v1`；adapter 只在未提供 `v1`
  的 base 后补 `/v1`，不接受 request URL、redirect、query、fragment 或 user-info。
  API key 单独写入 OS secure storage；配置记录不含 key。本机 Drift 历史只在 confirmed
  user text 写入后保存，streaming reply 每次增量持久化；取消、失败和 TTS
  故障仍保留已确认文本与已收到的完整/部分回复。
- `OpenAiCompatibleChatTransport` 只发送 Chat Completions 文字请求，解析
  `choices[].delta.content` SSE 与 `[DONE]`；禁用 redirect，并在 UTF-8 解码和
  `LineSplitter` 之前逐 chunk 限制原始响应字节总量，
  且不把 Authorization、key、prompt 或 upstream error body 写进公开错误。
  这与 Chat Completions 的 `POST /chat/completions` 和 SSE streaming 事实一致。
- `apps/client/test/direct_chat_controller_test.dart` 覆盖确认文本、增量流、
  本地历史、取消和不重发；`AGENT_TALK_FLUTTER_ROOT=/home/roco/develop/flutter-3.44.6
  npm run flutter:check` 于本次变更后通过，包含 analyze、Drift generation、format
  和 172 项 Flutter tests。受来源切换控件影响的既有 phone/desktop golden 已重建。

#### 2026-07-31 设置/本机 Piper 增量

- `VoiceProviderSettingsController`、配置模型和安全存储 record 与
  `VoicePortFactory` 将 STT/TTS 配置、端口构造和 Widget state 分离。生产
  `ProviderScope` 才注入 OS secure storage；离线 controller 默认使用 ephemeral
  store，因此任何纯文字/语音控制器测试不会意外访问系统 keyring。保存与恢复只接受
  受限字段，API key 仍只属于 Direct LLM 的独立 secure-store key。
- 来源设置页始终可从 Hermes 或 Direct LLM 路径打开：Hermes 只报告既有 paired
  Gateway 边界；Direct LLM 跳转其单独的 key/config form；faster-whisper 只可启用
  与测试应用拥有路径的 versioned sidecar readiness；Piper 只配置 exact loopback
  origin、可选 voice 与 speed。任一测试只显示安全失败阶段，不记录正文、音频或凭据。
- 新增 `PiperHttpTtsPort` 严格实现官方 Piper HTTP 表面：`GET /info` 为无文本
  readiness probe，`POST /synthesize` 提交文字并只接受最大 16 MiB 的 RIFF/WAV。
  redirect、远端 origin、user-info、path/query/fragment、坏 WAV、取消和服务错误均
  fail closed；TTS 失败仍由既有文字优先路径保留完整回复。Piper 引擎保持用户安装，
  不下载模型、不管理音色或 Python 环境。
- 离线证据新增 Piper loopback socket 契约、设置存储/独立测试、设置 UI widget
  测试；`npm test`、`npm run check` 和
  `AGENT_TALK_FLUTTER_ROOT=/home/roco/develop/flutter-3.44.6 npm run flutter:check`
  均通过。Flutter 门包含 analyze、Drift generation、格式、golden/accessibility 及
  178 项 tests；来源设置入口的六张 desktop/phone golden 因启用状态变化已人工检查并
  重建。

此增量补齐 M5 结构治理第 2 项的独立设置/adapter 边界，但不取代真实服务验收。

#### 2026-07-31 本机真实服务验收（历史脱敏证据）

- 复用 Hermes 的本机 `OPENROUTER_API_KEY`，但既未打印、持久化，也未写回 Client
  store。OpenRouter `GET /api/v1/models` 当时列出免费文本模型
  `inclusionai/ling-3.0-flash:free`。新 API base 路径以一次 `200` SSE probe 验证，
  随后对十条互不共享历史的已确认最小文字请求并发运行；十条均为 `200`、均收到
  `[DONE]`，下载量为 5,036–26,728 bytes。活动中的长 SSE request 在 2 秒后被
  显式 abort；`https://127.0.0.1:9/v1/models` 的 2 秒 connect probe 明确失败。
  请求体、回复和凭据都未进入证据文件或终端输出。该 transport 的 provider-neutral
  endpoint builder 另有 root/OpenRouter/unsafe-base 离线测试；
  `live_openrouter_smoke_test.dart` 默认 skip，只有显式
  `VOXHANDOFF_LIVE_OPENROUTER=1` 与环境 key 才执行，且为十轮外部测试设置 3 分钟
  timeout。当前自动化终端会在约 30 秒回收前台长请求，故本次将真实 HTTP 结果记为
  adapter endpoint 的服务验收，未把它表述为 Flutter GUI 人工操作录像。
- 在隔离 `/tmp/voxhandoff-m5-piper` Python 3.11 environment 安装官方
  `piper-tts[http] 1.6.0` 与免费 `en_US-lessac-medium` 声音（`63,201,294`
  byte ONNX）；它们不在仓库、不进 release bundle。实际 loopback HTTP server 的
  `/info` 返回 `200` JSON，`live_piper_smoke_test.dart` 以生产
  `PiperHttpTtsPort` 完成 warm-up 和 synthesize，接收超过 WAV header 的 RIFF/WAV。
- `services/stt` 依据既有 `uv.lock` 安装 `faster-whisper 1.2.1` 并以 tiny model
  运行真实 JSONL。Piper 生成的短暂英文 WAV 经本机 ffmpeg 重采样为 16 kHz PCM；
  sidecar 在 `health → warmup → start → push(sequence=1) → end` 输出非空 final
  text，元数据报告 `audio_duration_ms=1115`。首次错误地发送 `sequence=0` 时
  sidecar 正确返回 `stt_audio_sequence_invalid`，随后修正为 1 后成功；这同时验证
  了 fail-closed sequence gate。生成的 WAV/PCM/JSONL 仅在 `/tmp`，记录中只保留
  frame metadata 和“是否有文字”，不保留音频或转写正文。
- 以上是“本地真实服务 + 合成音频”链路，证明可配置端口、受限协议、流式文本、取消、
  离线失败和文字优先降级可组合；它不是用户对着物理麦克风完成的 GUI 录音验收，也
  不能替代 Hermes H1 的 Flutter→Gateway/PostgreSQL→Connector→Hermes 纵向门。实际发行前仍
  须在目标桌面实体麦克风完成录音—编辑—发送—回复—播放并记录同样脱敏的事实。
- 最终回归在 Flutter 3.44.6 通过 analyze、Drift generation、format、golden、
  accessibility 与 183 项 tests（另有上述两个 opt-in live tests 默认 skip）；
  `npm test`、`npm run check` 和 `git diff --check` 同时通过。

这组证据证明的是当日真实服务 adapter/sidecar 的受限接口，不是完整 GUI 发行验收；
不能与“当前机器是否已配置这些服务”混用。本轮收尾时，只有在目标桌面存在可授权的
实体麦克风、用户配置的 HTTPS LLM、可运行 STT 与 Piper 服务，并能由人工完成一轮
“录音—编辑—明确发送—流式回复—播放”后，才能关闭 M5 的物理设备退出条件；任何
fake、合成音频、transport smoke 或离线测试都不能替代它。

#### 2026-07-31 M5 安全修复收尾

- Gateway 现在把 conversation 的持久化 `(node, agent, capability revision, session)`
  当作唯一权威 route。发送、恢复、outbox claim 和 Node event 均从账本取 route；Client
  发送任一不一致字段即 `conversation_route_mismatch`，同一 route 下的非空 session 不可
  被另一个 conversation 复用。PostgreSQL integration fixture 覆盖跨 conversation
  session 复用、lease/route 绕过和重连 claim；本轮在临时、仅 loopback 的 PostgreSQL
  17.10 容器中以空数据库完成 migration、acceptance、reconnect 与 convergence 验收。
- 已按本机安装的 Hermes Agent 0.19.0 源码核对 approval resolution：上游 API 只接受
  `choice`，内部对 pending queue 执行 FIFO `pop(0)`。Connector 因而不再把 approval
  B 的决定转发给可能仍在队首的 A；它公布 approval 不可用，并以
  `hermes_approval_resolution_ambiguous` 拒绝任何此类 decision。fake Hermes 回归断言
  两个 pending approval 时，对 B 的拒绝不会调用 upstream resolution。
- Direct LLM SSE 在 UTF-8/分行之前限制原始字节：持续无换行、超长单行、正常分片、
  取消和 timeout 都有独立 Flutter 回归，防止 `LineSplitter` 前无界累积。
- Node 的 JSON Hermes session store 以共享加载 promise 串行冷启动；同一 conversation
  的并发 dispatch 只会创建/持久化一个 session，受控并发回归覆盖磁盘加载未完成时的
  两个 dispatch。

上述四项是已实现且已通过各自离线自动化验证的安全修复；它们不改变 Hermes H1 的
`idempotency=false` fail-closed 门。M5 实现、真实 PostgreSQL 与服务 adapter 证据仍可供
后续阶段使用，但物理麦克风 GUI 全链路和 H1 真实纵向链路必须在具备对应外部条件后
单独记录，不能宣称为已通过。本轮桌面诊断确认 Fedora 44/Wayland 与 PipeWire 可见两个
内建麦克风和扬声器；没有 Live OpenRouter opt-in/key，也没有可辨认为 STT/Piper 的验收
服务监听端口，因而没有擅自发起外部请求或用合成输入替代人工 GUI 操作。恢复条件是在
用户配置的 HTTPS LLM、STT、Piper 和实体麦克风均可用时人工执行一轮完整 GUI 流程，
只保存脱敏阶段/结果证据。

#### M5 结构治理 — 2026-07-31 历史解耦计划

本小节保留当时的职责拆分顺序；涉及 Direct LLM 安全和统一助手的当前执行顺序，以后文“后续开发批次”为准。不能用纯结构拆分替代批次 1、2 的行为修复。

触发条件：M5 的来源选择、用户自接 LLM API 的一轮文字/流式回复，以及录音到可编辑终稿的主路径均已有契约测试。它是 M5 的维护性门，不应抢在主路径可用之前，也不与 Hermes H1 的上游能力阻断混在同一变更中。

执行原则：一次只移动一个职责边界；先为旧行为补齐单元/契约测试，再移动实现；每个切片保持 wire schema、数据库 migration、公开 UI 语义和安全语义不变。生成的 `*.g.dart`、Protobuf binding 与 `dist/` 不作为手工解耦对象。任何拆分造成 `uncertain`、审批、秘密隔离、cursor 或完整回复语义变化，必须停止并单独走规格变更。

优先顺序：

1. `apps/client/lib/presentation/home_screen.dart`：按导航、会话选择、空状态、会话工作台拆出纯展示 Widget；Widget/golden/accessibility 测试保持覆盖。这是低风险第一切片，可与来源选择 UI 同步完成。
2. 用户自接 LLM API、STT/TTS 设置：将 provider 配置模型、OS 安全存储、连接测试和 UI form 保持为独立层；界面不直接读取 key，adapter 不持有 Widget state。该边界随 M5 新功能建立，避免形成新的聚合文件。
3. `services/node/src/hermes-node-connector.ts`：在 H1 之前按 session 映射、dispatch、SSE 翻译和 interaction command 拆分；保留一个薄的 lifecycle coordinator，并以 fake Hermes/Gateway stream 契约测试保护。
4. `services/gateway/src/postgres-ledger.ts`：在 M5 闭环验收后、任何新的 Gateway 特性之前，按 request/event、lease、approval/clarification 与事务基础设施拆分；共享 transaction 保持单一提交边界，真实 PostgreSQL integration tests 不得降级。
5. `apps/client/lib/infrastructure/storage/drift_client_event_ledger.dart`：最后分离 schema/SQL、事件映射、读模型与清理策略，保留事件与 cursor 的原子提交和重启恢复门。

完成条件：上述每个切片独立提交、独立通过相关质量门；不以行数为目标，不做跨模块“顺手清理”。M5 结束时至少完成第 1、2 项并记录其余项的现状；第 3–5 项可在不阻塞 H1 或发布门的前提下继续推进。

### H1 — Hermes 单一纵向链路（内部链路已实现；上游能力阻断真实端到端门）

目标：只把 Hermes 做成可真实使用的首发 Agent。

- capability fail closed，固定 SSE event identity、sequence、`Last-Event-ID` 与断线恢复；
- 生产 Node Connector 接通配置/secret、Gateway 注册、session、run、SSE、stop、approval 和错误；
- Gateway 接受后的 start 结果不明不得再次调用 run，只允许状态/事件恢复；
- 审批字段不完整时 fail closed，所有决定继续受 device signature、scope、lease、expiry、operation hash 和 idempotency 保护；
- 在明确广告并满足所需 capability 的隔离 Hermes release 上完成真实 Flutter 客户端、Gateway/PostgreSQL、Connector 的 10 轮、stop、approval、非优雅断线与 Connector/Gateway 重启；证据记录 exact Hermes version/commit。Hermes 0.19.0 只保留为原始历史目标和负向兼容样本。

退出条件：真实端到端门全部通过，事件和 session 不串线，没有重复执行、自动审批、秘密日志或把连接丢失误报为失败/完成。fake Hermes 只证明 Connector 契约，不满足退出条件。

当前实证：直接 Hermes 0.19 adapter 已通过 10 轮、stop、manual deny、SIGKILL uncertain 和 gateway 重启/session resume；该版本未广告幂等 run capability，生产 Connector 将缺失能力协商为 `idempotency=false` 并正确拒绝注册，这是当前第一个外部阻断。H1 的历史退出矩阵明确包含 approval，因此完整 H1 的第二项必需上游能力是不可变 approval identity 与按 ID 精确 resolution；0.19 只接收 `choice` 并 FIFO 消费队首，不能满足该门。两项能力均不得以版本推断、自动重提或放开 Connector fail-closed 代替。

### M6 — Hermes MVP 界面与真实负载（UI/Fedora 60 Hz 门完成；移动 120 Hz 待验）

目标：将底层事件变成可长期使用的对话界面，并让 SignalCore 成为原创、实时、可访问的状态主体。

- request 事件聚合为用户轮次、完整 Hermes 回复、可折叠工具轨迹、未决交互和终态；
- 修复跨请求失败污染与错误 active request，delta 不再生成独立卡片；
- 拆分 HomeScreen，将高频 audio level 隔离到局部 consumer，长历史使用虚拟化列表；
- PCM 包络在 isolate 中分析，迟到 generation/segment 结果丢弃；
- SignalCore 状态形变、音频响应、静态回退、无障碍标签和 reduced-motion；
- 500 条桌面/2,000 条手机历史 widget gate，以及 actual HomeScreen 的 delta + recording + TTS + shader 并发 profile。

退出条件：固定 Flutter SDK 的 analyze、全部 widget/golden/accessibility test、Linux release 和实际 HomeScreen profile 通过；手机不一次构建全部历史，idle 无持续帧，正文与审批始终优先且可读。

完成证据：Flutter analyze、170 项 test、Linux x64 release build 和 runtime-effect 编译通过；桌面 500/手机 2,000 条长历史 widget gate 均通过。Fedora 44 release 的 2,000 事件实际 HomeScreen stress/idle P95 分别为 12,759/12,964 µs，低于 60 Hz 的 16,667 µs 门，证据位于 `artifacts/benchmarks/mvp-fedora44-20260729/`。120 Hz 实体手机 profile 仍是跨设备性能限制，不改写本里程碑的 Fedora 首发结论。

## 5. 后续开发批次

以下批次不新增里程碑编号，而是在既有 M5、M6、H1 内关闭剩余问题。顺序是强约束：先修复身份、凭据、目标与终态的一致性，再建立统一助手和长期上下文，之后关闭真实语音与设备门，最后在上游能力具备时执行 H1。除批次 7 外，均不依赖 Hermes 改版。

### 5.1 批次 1（M5）：Provider Profile、历史隔离与确认目标快照

- **用户需求**：切换 API 服务、模型或 Hermes 目标时，密钥、历史和已确认文字都只发送给用户明确看到并确认的目标。
- **批次 1 前的问题（已关闭）**：生产设置路径只有一个 active configuration，首次 ID 为 `default-direct-llm`；编辑 origin 或 model 会复用该 ID，空 key 会继续读取该 ID 下的旧 key，全部历史也按同一 ID 复用。`confirmDraft()` 只确认文本，实际发送时才读取当前 ChatSource/configuration 或 Hermes conversation，因此确认后切换目标不会强制重新确认。
- **实施范围**：引入 opaque `providerProfileId`、独立 `credentialRevision`、`configurationRevision` 和本地生成的 `conversationId`。origin/auth realm/principal 变化必须创建新 Profile；同身份 key rotation 递增 credential revision；model 或采样参数变化创建 configuration revision，并默认开启新 conversation。批次 1 先生成并持久化一个 opaque default `assistantId`，建立最小 `AssistantProfile { assistantId, assistantRevision, systemPrompt }`，把现有 Direct system prompt 迁入这个唯一权威；批次 3 再扩展完整助手配置和统一界面。实现架构定义的完整 `ConfirmedDraft { draftId, draftRevision, confirmedText, textHash, assistantId, assistantRevision, contextSnapshotRevision, contextSnapshotHash, chatSource, conversationId, targetSnapshot, confirmedAt }`；Direct target 固定 Profile、credential/config revision 与 conversation，Hermes target 固定 conversation 及权威 `(nodeId, agentId, capabilityRevision, sessionId)` route，其中 `nodeId` 是安全意义上的执行主机身份。任何绑定字段变化都销毁确认快照。
- **状态和数据语义**：Profile 是服务/auth 边界，credential/config revision 是不可变请求快照，conversation 是历史边界，不能复用一个 ID。批次 1 先落最终 `local_messages` terminal/provenance schema 与 legacy migration，批次 2 再把 runtime lifecycle 完整接到该 schema；两批之间不得再做第二次终态 schema 迁移。旧配置、secret 和消息迁移为禁用 legacy records：旧消息虽有 `providerId`，但该 ID 曾跨 origin 复用，因此 origin/revision/conversation provenance 不可信；旧 assistant message 使用 `terminal=incomplete` 加独立 `provenance=legacy_unverified`，只可查看、导出、删除。旧 secret 保持隔离且不得用于测试或聊天；用户看到 exact normalized origin/auth realm 后重新输入 key，才创建可用 credential revision，成功后删除旧 secret reference。
- **安全边界**：新建 Profile、改变 origin/auth realm/principal 或重新激活 legacy 配置时必须输入非空 key；当前 adapter 不定义无认证模式。只有同一 active Profile 且不执行 rotation 时，空输入才表示保留原 key。历史跨 Profile 迁移默认禁止；显式迁移必须预览目标、范围和会发送的数据。确认界面展示实际 provider/origin/model/credential revision 或 Hermes node/agent/session，不以 display label 作安全判断。
- **主要影响模块**：`apps/client/lib/domain/direct_chat.dart`、`domain/client_session.dart`、Direct LLM/ClientSession/ChatSource controllers、secure store、Drift Direct chat store、设置页、消息输入区，以及相应 migration 和 tests；Hermes route 仍复用 Gateway 已持久化的权威 tuple，不新增第二份路由真相。
- **批内实施顺序**：先用当前实现写出会失败的 key/history/target-switch 回归；再做 forward-only Drift schema、default assistant identity 与 legacy secret/history 隔离 migration；随后接 Profile/revision CRUD 和 request payload；最后替换 `confirmDraft()`/composer UI 并做人工双 provider 验收。第一提交不改统一主页、记忆或语音 UI。
- **自动化验收**：覆盖“origin A 的 key 不会发送给 origin B”“legacy secret 不能测试/聊天且重输前 Profile disabled”“rotation 递增 credential revision 并撤销测试证明/确认”“Profile B 不接收 Profile A 历史”“model/revision 变化不改写旧 conversation”“assistant/system prompt 或 context-eligible message revision 变化撤销确认”“发送正文来自 immutable confirmedText”“确认后切换 source/Profile/conversation/node/agent/revision/session 必须重新确认”“legacy provenance 不进入 payload”“最终 terminal/provenance schema 的 migration 中断可安全恢复”。相关 Flutter unit/widget/migration tests 与固定 SDK `flutter:check` 通过。
- **人工验收**：使用注入式 integration harness 创建两个带规范 HTTPS origin 的 deterministic fake provider，分别保存不同 key 和历史，逐项切换 origin/model/Profile/source/Hermes target；发送前界面目标与 fake 捕获结果一致，空 key 不继承错误服务商凭据，旧确认不可提交。harness 不发真实网络请求，也不得放宽 production HTTPS/TLS 规则。
- **外部依赖**：无；使用现有 OS secure storage、Drift 和 Gateway route。loopback fake 不需要真实 API。
- **完成条件**：代码和存量数据中不存在“配置 ID 同时充当 provider、credential 和 conversation 身份”的活动路径；legacy key/history 默认不可发送；所有发送只接受 assistant/context/backend revisions 仍有效的 `ConfirmedDraft`。这是下一轮 Luna Max 的首个开发任务，也是 PR #4 转为可评审前的第一项正确性门。

**2026-08-01 批次 1 实现证据**：已落地 `ConfirmedDraft`、default assistant identity、Provider/credential/configuration/conversation revision 和 `contextSnapshotHash`；Direct secret/config 改为 v2 key space，origin/auth realm/principal 变化创建新 opaque Profile，模型变化创建新 configuration revision/conversation，同身份 rotation 递增并删除旧 credential revision。旧 v1 config/secret 不被读取；旧 Drift message migration 进入 `legacy-<providerId>` 隔离 conversation，写入 `terminal=incomplete`、`provenance=legacy_unverified` 和 `context_eligible=false`。消息表已从 `completed` 布尔值改为受约束的 `streaming|completed|cancelled|failed|incomplete|truncated` terminal、provenance、revision 与 context eligibility。确认和发送回归覆盖 origin key/history 隔离、Profile disabled、revision/conversation 隔离、source/Profile/conversation/route target switch、immutable text/target/context hash；`npm run flutter:check` 于本批次 head 通过（Flutter analyze、195 tests；2 个显式 live smoke skipped）。批次 2 仍负责把所有 Direct lifecycle/ bounded I/O 完整映射到这些终态。

### 5.2 批次 2（M5）：Direct LLM 请求所有权、消息终态与有界 I/O

- **用户需求**：取消、切页、切换配置、超时或服务异常后，旧请求不能污染当前对话、误播 TTS 或把残缺回复伪装成成功；Direct LLM 也不应依赖 Gateway 在线才能发送。
- **当前问题**：连接测试与聊天流共享 transport 的单一 `_active` 请求；切 source/Profile/config 不取消旧流，隐藏页面仍可写历史和触发 TTS。批次 1 已落最终 terminal/provenance schema，但 runtime 仍把任意自然 EOF 当作 `completed`，且尚未完整区分 `[DONE]` 缺失、超时、超限与部分失败。`GET /models` 与 chat 非 2xx body 仍是无界 `drain()`；delta 每片同步写 SQLite；Direct 输入区复用了要求 Gateway connected 的 `canSubmit`。
- **实施范围**：以 request ID + assistant/Profile/revision/conversation 作为 request owner；连接测试使用独立句柄。切 source、Profile、revision、conversation 或退出当前聊天上下文时，先 cancel 并等待 terminal barrier，再激活新目标；旧 generation 的 delta、terminal 和 TTS token 一律丢弃。复用批次 1 已落地的最终 terminal/provenance schema，把 runtime lifecycle 完整映射为 `streaming | completed | cancelled | failed | incomplete | truncated`，保存 stage/error code/received bytes；所有 response path 使用同一有界 reader 和总时限。delta 最多每 250 ms 合并写入一次，terminal 立即落盘。Direct submit readiness 与 Gateway connection 分离。
- **状态和数据语义**：只有收到协议认可的完成标记且解析结束才是 `completed`；用户取消为 `cancelled`；未产生有效正文的连接、认证、超时、网络或 protocol 错误为 `failed`；已有部分正文却缺少完成证明，包括提前 EOF、缺 `[DONE]`、超时、断网或后续解析失败，均为 `incomplete`；超过响应上限为 `truncated`。迁移时旧 assistant reply 一律为 `terminal=incomplete`，另设 `provenance=legacy_unverified`；该 provenance 不是第七终态，只展示且不自动进入上下文或 TTS。
- **安全边界**：cancel 不得转成 retry；失败或部分回复不得自动重提；非 2xx body 只在上限内消费后丢弃，仅保存 HTTP status、stage、稳定错误码和 allowlist request ID，不保存或展示 upstream body 摘要；只有当前前台 conversation 的 `completed` reply 可进入自动播报。TTS 有独立 generation token，录音开始、目标切换、配置变化或新 reply 都能取消旧 generation。
- **主要影响模块**：OpenAI-compatible client、DirectChatController/Provider、TTS controller、HomeScreen/MessageComposer、Direct message schema/store 与 adapter/controller/widget tests。
- **自动化验收**：覆盖无 `[DONE]` EOF、EOF with partial、cancel before/after delta、connect/read timeout、网络断开、超限、非 2xx 超大 body、`/models` 超大 body、test/chat 并发、source/Profile/page 切换、迟到 delta/TTS、写入合并、terminal crash recovery，以及 Gateway 离线时 Direct chat 可用。用 fake clock/stream 保证无 30 秒悬挂测试。
- **人工验收**：对 loopback SSE 服务注入慢流、断流、超大错误和迟到 chunk；UI 显示准确终态，历史不串线，无隐藏播报，取消立即可见且不自动重发。
- **外部依赖**：无；真实 OpenRouter 只作为批次结束后的补充证据，不替代 failure fixtures。
- **完成条件**：每个请求有唯一 owner 和唯一 terminal；所有 body 均受 byte/time limit；重启后不会把非完成回复当作已完成上下文；Direct 聊天可在 Gateway 完全不可用时独立工作。

**2026-08-01 批次 2 实现证据（本轮）**：Direct controller 已以 request ID、配置对象和 generation 作为 owner；source/Profile/configuration 变化先 cancel 并等待本地终态写入；连接测试与聊天使用独立 transport request handle；SSE 只有收到 `[DONE]` 才完成，空失败/partial/超限分别写入 `failed/incomplete/truncated`，delta 最多每 250 ms 合并写入且 terminal 立即落盘；request 1 MiB、response/error body 4 MiB 且均有有限 timeout；Direct composer 不再要求 Gateway connected。新增 profile/source switch、终态映射和迟到结果回归。固定 Flutter 3.44.6 的 `npm run flutter:check` 通过（analyze、201 tests passed、2 个显式 live smoke skipped）。本轮仍未把真实非 2xx 超大 body loopback 作为独立 transport fixture，保留为补证项。

**2026-08-02 批次 2 独立 transport 补证（本轮）**：`apps/client/test/openai_compatible_chat_client_test.dart` 新增真实 loopback `HttpServer` fixture，分别覆盖 `GET /v1/models`（503）和 `POST /v1/chat/completions`（502）；每个响应发送 4 MiB 上限之外的 4.5 MiB body，并以 64 KiB 分块记录 client 在 bounded reader 终止前的消费边界。transport 只返回 `llm_stream_too_large`、`protocol` stage、HTTP status 和固定安全文案；`DirectChatFailure` 保留 stage/status/code，upstream body sentinel 不进入错误文案。按现有 controller 语义，该超限错误落为 `truncated`（无有效正文时仍不触发 TTS/上下文），而非 2xx 且未超限仍为 `failed`。锁定 SDK `flutter analyze --no-pub` 通过；本受限执行环境禁止 loopback listen，目标 `flutter test --no-pub test/openai_compatible_chat_client_test.dart` 在测试加载阶段以 `Operation not permitted` 退出（1），须在允许 loopback 的 runner 复跑该独立 fixture 后再把运行态证据标为通过。

### 5.3 批次 3（M5）：统一助手配置与 capability 化界面

- **用户需求**：用户始终面对同一个有名称、人格、声音、记忆和视觉表现的个人助手；Direct LLM 聊天与 Hermes 工作是同一助手的不同能力，而不是两个产品入口。
- **当前问题（本轮前；最小客户端边界已关闭）**：当前状态曾以 ChatSource、Direct 单例配置、Hermes conversation、TTS/STT 设置和 SignalCore 分散持有；现已建立本地 AssistantProfile、voice assistant binding 与 capability projection，但完整的统一内容 shell/多助手管理仍不是本轮扩展目标。
- **实施范围**：扩展批次 1 已创建的最小 AssistantProfile，增加名称/人格、memory policy、STT/microphone、TTS/voice/speed/language、SignalCore、默认聊天后端、Hermes work backend、播报与打断策略；system prompt 继续只由 AssistantProfile 拥有，不在 Provider revision 建立第二来源。首版只要求一个 active assistant，但所有新数据携带 `assistantId`。统一 conversation shell、消息列表和 composer；Hermes 工具轨迹、approval、lease、执行主机和真实 Agent state 仅在 Hermes capability 可用时展示，Direct LLM 永不模拟这些状态。
- **状态和数据语义**：AssistantProfile 只保存 secret reference；Provider Profile、Hermes route 和 conversation 仍是独立实体。conversation 创建时固定 backend binding；显式 handoff 创建新 conversation/branch，不原地改写旧历史。现有 voice/visual/Direct 设置以版本化 migration 合并到默认 assistant，保留可回滚备份直到 migration commit。
- **安全边界**：统一视觉不等于统一授权。Direct LLM 无 Agent、tool、approval、lease 或 remote execution 语义；Hermes 的原生状态只来自 Gateway ledger/Connector。首版不得把本地 persona、固定记忆或 Direct system prompt 自动注入 Hermes，除非后续规格明确并由用户启用。
- **主要影响模块**：client domain/state/storage、HomeScreen/navigation/settings、SignalCore、Direct/Hermes presenters、secure reference mapping 与 migrations；Gateway/Connector wire protocol 不因 UI 统一而改写。
- **自动化验收**：AssistantProfile migration、backend capability projection、conversation binding、Direct 不出现 Agent 控件、Hermes 状态只读权威事件、切 assistant/backend 后确认失效、voice/visual 设置按 assistant 恢复；widget/golden/accessibility 和长历史测试保持通过。
- **人工验收**：从同一助手主页分别开始陪伴聊天与 Hermes 工作；名称、人格、SignalCore 和音色连续一致，但只有 Hermes 会话出现工具轨迹、审批、lease 和执行主机，切换时无历史或状态串线。
- **外部依赖**：无。Hermes H1 live 能力不是构建统一 shell 的前置条件，可用 fake capability 完成离线验收。
- **完成条件**：产品主导航不再以“两个互不关联的来源”组织体验；一份 AssistantProfile 可完整重建基础展示与语音偏好，backend 差异通过 capability 明示且不伪造状态。

### 5.4 批次 4（M5）：conversation 级上下文、固定记忆与滚动摘要

- **用户需求**：长期陪伴聊天能记住用户允许保留的信息，同时上下文有界、可理解、可查看、可编辑、可删除，并且不会跨服务商或 conversation 泄露。
- **当前问题（本轮前；确定性 builder/storage 已关闭）**：当前 Direct 请求曾每轮发送该单例下的全部消息；现已接入 conversation context budget、固定记忆、确定性本地 summary、删除/编辑语义和 partial reply 排除。真正由 LLM 自动生成摘要与可编辑 policy 仍单独保留。
- **实施范围**：为每个 conversation 保存单调 `contextSnapshotRevision` 和 context policy，按 `system prompt → 已授权固定记忆 → 带覆盖范围的滚动摘要 → 最近 completed turns` 组装 payload；在不引入 tokenizer 依赖的首版使用可测试的 UTF-8 byte budget，并为输出保留固定余量。固定记忆支持查看、编辑、删除和作用域；摘要保留 source range、生成 backend/Profile/revision 和更新时间，永不覆盖原始历史。预算不足时先丢弃最旧最近轮次；system prompt 或固定记忆单项自身超限时拒绝发送并要求裁剪，绝不突破硬预算。
- **状态和数据语义**：原始消息、摘要和固定记忆是不同记录；`cancelled/failed/incomplete/truncated` 或 `provenance=legacy_unverified` 的 reply 默认不进入上下文，provenance 与 terminal 分列。摘要只能覆盖同一 assistant/conversation/backend binding 的已完成轮次；任何 context-eligible message set/content/terminal、memory、summary 或 policy 变化都递增 context revision 并撤销旧确认；当前 confirmed user text 的预发送落盘不递增，assistant reply 进入 `completed` 后才为下一轮递增。切 Profile/迁移 conversation 后重新生成或显式不携带。删除立即从读模型和未来 payload 消失，后台压缩/清理不得阻塞当前发送。
- **安全边界**：记忆默认仅存本地；用户可见具体哪些记忆会随下一请求发送。摘要只能由当前 conversation 已选择的同一聊天后端生成，不把数据送往第三方“摘要服务”。任何向 Hermes 注入个人记忆的能力保持关闭，等待单独产品决定和显式授权。
- **主要影响模块**：Direct conversation/message store、memory/summary repositories、context builder、settings/memory UI、request payload fixtures、diagnostic export/redaction。
- **自动化验收**：conversation 隔离、确定性预算边界、组合顺序、partial 排除、摘要覆盖不重叠、固定记忆 CRUD、删除后不再发送、Profile 切换不带旧摘要、重启恢复、长历史性能与日志脱敏。
- **人工验收**：建立两个 conversation 和两个 Provider Profile，分别添加/编辑/删除固定记忆并产生足够长历史；发送前预览与 fake provider 捕获 payload 一致，旧 conversation、已删除记忆和残缺回复均未出现。
- **外部依赖**：无强制依赖；若未来引入精确 tokenizer，须单独记录模型覆盖、许可证、体积和 fallback。
- **完成条件**：请求上下文始终受确定性预算约束；用户能解释并控制发送内容；长期会话不会因历史无限增长而持续放大请求或 SQLite 写入压力。

**2026-08-01 批次 3/4 本轮实现证据**：AssistantProfile 已从批次 1 的最小
`assistantId/assistantRevision/systemPrompt` 扩展为本地聚合身份，持久化名称、人格、记忆策略、
voice/SignalCore 引用、默认 chat backend、Hermes work backend 和播报策略；voice settings
同时保存当前 `assistantId/assistantRevision`，由 HomeScreen 在 active Assistant 恢复后绑定。
Direct banner 与 Hermes banner 共用 Assistant 语义，Direct 的 capability projection 只有
`chat`，Hermes 只有在 Gateway directory 广告对应能力时才在无障碍语义中报告 approval、interrupt
或 clarification；工具、lease、执行主机仍只读真实 Hermes 事件，不由 Direct 模拟。

批次 4 已新增独立的 Drift context memory/summary 表（schema 3），按 conversation 隔离固定记忆和
滚动摘要；`DirectContextBuilder` 按 system prompt → fixed memory → rolling summary → 最近
completed turns → 当前 user 的顺序组装，使用 UTF-8 48 KiB 输入预算并保留 8 KiB 输出余量，排除
cancelled/failed/incomplete/truncated/legacy 回复，摘要 target 或 source range 不匹配时拒绝发送。
Direct request 现在只发送 builder 的实际结果，设置页支持 memory 查看/编辑/删除、summary 本地重建
和清空；`contextSnapshotHash/revision` 会随消息、记忆、摘要或 Assistant identity 变化而撤销确认。
新增 builder、预算、target isolation、Drift CRUD 与 Assistant identity 回归；固定 Flutter 3.44.6
门通过（208 tests，2 个显式 live smoke skipped）。

本轮刻意没有把“由当前 LLM 自动生成滚动摘要”或可调 tokenizer/policy 做成隐式请求：这会增加费用、
递归摘要、失败终态和数据外发边界，应作为独立产品决策。当前提供的是不联网的确定性本地 summary
rebuild 和固定安全预算；若要求真正的 LLM 摘要，必须另定义其确认、失败、版本和删除语义。

### 5.5 批次 5（M5）：语音配置、真实 GUI 闭环与可打断交互

- **用户需求**：用户可选择麦克风、STT、TTS、音色、语速、语言和播报策略，并在真实 GUI 中完成连续、可打断的个人助手对话；任一语音服务失败仍保留文字聊天。
- **当前问题**：本轮已补齐 GPT-SoVITS 的完整设置入口与播报策略（关闭/手动/完成后自动）的本地实现；剩余是移动端 remote STT、真正的 bundled executable 产物、连续 GUI 与实体麦克风验收。当前 Linux release 仅在显式提供 sidecar 时安装它。真实服务与合成音频证据不等于 production bundle 或实体麦克风 GUI 验收。
- **实施范围**：在 AssistantProfile 下提供可枚举且可诊断的 microphone/STT/TTS 配置。GPT-SoVITS 暴露 adapter 已支持的 loopback origin、reference audio、prompt text、prompt/text language；播报策略持久化为 `off|manual|afterCompleted`，完成后自动播报与手动逐条播报共享同一 generation/取消边界。Piper 只解析和展示官方 `/info` 广告的 voice/speaker/language；用户 `speechRate` 与 Piper `lengthScale` 的方向和边界保持明确、单调、可测试。desktop release 把受信 `voxhandoff-stt` 安装到规范 `libexec` 路径并验证 version 1.0 JSONL；STT Profile 要求用户选择已存在的 canonical local model path，缺失时 fail closed，production sidecar 禁止用模型名触发下载或回退 PATH。remote STT 暂不在本轮伪造通用生产入口：当前仓库只有 provider-specific adapter，没有统一的 versioned provider/credential/retention contract；它保留为 desktop/mobile 独立实现与同意 UI 任务。无设备枚举能力的平台明确显示“系统默认/不可选”。
- **状态和数据语义**：recording、transcribing、confirmed、sending、reply terminal、synthesizing、playing 分属独立但可关联的 generation。开始录音立即停止本地 TTS/playback，但不把 Hermes remote run 误当作已停止；新的 backend/config/conversation 只影响新 generation。STT/TTS failure 写入具体 stage，确认文本和完整回复保持可编辑、可复制、可重试语音。
- **安全边界**：raw recording 默认本地且按策略清理；production local STT 只接收用户选择的本地模型目录，缺失/损坏时不联网下载；remote STT 每个 exact origin 首次上传必须确认，origin 变化重新确认；远程 TTS 首次发送回复文字及 origin/TLS/保留事实变化时同样重新确认；凭据只在 OS secure storage；TTS 不朗读未完成回复、秘密字段、approval payload 或隐藏 conversation。连续免手模式默认关闭，只有明确启用和可见麦克风状态时运行。
- **主要影响模块**：audio capture/record adapter、STT/TTS ports 与 factories、desktop build/install packaging、Assistant settings、voice session controller、TTS playback、mobile platform wiring、HomeScreen/SignalCore 与 live acceptance harness。
- **自动化验收**：每个 adapter 的 config round-trip、Piper capability/field mapping、speaker forwarding、speechRate/lengthScale 单调边界、credential isolation、remote STT/TTS exact-origin consent、language forwarding、bundled executable manifest/版本/protocol、无本地模型且禁网时 fail closed、设备断开、record/TTS generation race、迟到结果丢弃、语音失败文字保留、无设备/无服务降级，以及现有 Flutter 全套检查。
- **人工验收**：在 Fedora release GUI 连续完成 10 轮共享历史的 Direct conversation，其中至少一轮使用实体麦克风执行完整 `录音 → STT → 编辑/确认 → Direct LLM → completed 回复 → TTS → 播放/停止`；同一验收矩阵另覆盖一次打断、一次取消、一次 STT 失败、一次 TTS 失败、一次 Profile/source 切换，并确认 release app 实际从 bundle 启动 sidecar、只使用指定本地模型。分别记录 GPT-SoVITS 与 Piper 可用配置。移动端 remote STT 另在一台具名设备完成权限、上传同意、断网和恢复验收。
- **外部依赖**：用户提供的本地 STT 模型、loopback/remote STT、GPT-SoVITS/Piper 服务和至少一台实体移动设备；这些服务不可用时只阻断相应 live 证据，不得破坏文字模式。
- **完成条件**：文档明确区分 adapter 存在、配置入口、production bundle、自动化、真实服务和 GUI/实体设备证据；M5 的唯一关闭口径是 10 轮连续 GUI Direct conversation 且其中至少一轮完成实体麦克风全链路，所有失败都能安全降级为文字。免手常听与移动发布门不借此宣称完成。

**2026-08-01 批次 5 本轮实现证据**：Voice settings 现在可保存 STT language、已存在的 local model directory、Piper voice/speaker/speaker ID、GPT-SoVITS origin/reference/language 和用户语义的 speech rate；生产 VoiceSession 将 language 与 microphone ID 传给 STT/capture，`record` adapter 可枚举并选择输入设备，平台不提供枚举时明确使用系统默认。Piper `/info` 严格解析官方 `voice.name/language/num_speakers`，synthesis 的 speaker 字段和 bounded WAV/error body 有离线测试；GPT-SoVITS 配置 round-trip 与语言字段进入安全校验。AssistantProfile 的播报策略已进入设置入口：`off` 不播报，`manual` 在 completed reply 上显示逐条播报动作，`afterCompleted` 才自动调用已有 TTS generation。sidecar CLI 无模型目录以 exit 2 fail closed，不再把 `base` 交给引擎，Linux CMake release 仅在显式提供 executable 时安装 `libexec/voxhandoff-stt`。本轮 Flutter 门为 209 tests passed、2 个显式 live smoke skipped；Fedora Linux release 构建通过但本机未提供 sidecar executable，生成 bundle 明确没有 `libexec/voxhandoff-stt`，因此只能作为 text-first degraded build。实体 GUI、实际模型/服务、remote STT 和 production sidecar 产物仍未关闭。

**2026-08-02 STT sidecar 打包补项**：选定 PyInstaller `--onefile`，以 `services/stt/scripts/build-linux.sh` 固定 Python 3.11、`uv.lock` runtime 和 `packaging/requirements-build.txt` 的构建工具版本；`zipapp` 因目标机仍需 Python 且不管理 native dependencies，`uv build` 因只产出 Python distribution archive，均不满足 launcher 的独立 `libexec/voxhandoff-stt` 门。新增 PyInstaller entrypoint、构建参数、缺失模型 CLI 回归测试和 Linux release/CMake 两阶段命令文档。当前 worktree 的 `npm run test:stt` 为 10 tests passed；本机真实 base model 上 source sidecar 的 version 1.0 `health`/`capabilities`/`warmup` 分别返回 `cold`、PCM16LE mono 16/24/48 kHz、`warm`；缺失模型保持 exit 2。实际 PyInstaller artifact 与带真实 artifact 的 Flutter bundle 尚未在本环境形成：执行构建时 uv 无法解析 PyPI DNS，无法下载 lock 中的 `ctranslate2`；因此不能把 bundle 路径、体积或发行门写成已通过。固定 Flutter 3.44.6 不暴露任意 CMake `-D` CLI 参数，README 记录先 `--config-only` 再用同一 release cache 注入 `-DVOXHANDOFF_STT_EXECUTABLE`/`-DVOXHANDOFF_REQUIRE_STT_BUNDLE=ON` 的可重复命令；CI/发布机仍需执行该门并验证 `bundle/libexec/voxhandoff-stt`。

**本轮规格合理性复核**：将“security workbench”作为 PR 阶段门没有对应的产品条款或验收，不应继续阻断 M5；GPT-SoVITS 和播报策略已具备本地配置/自动化边界。remote STT 不能在缺少统一 provider、凭据、TLS/保留和移动同意 contract 时靠一套泛化表单“完成”，移动端 remote STT、签名安装包和实体设备矩阵属于独立发布/平台证据轴，也不应被本地 Fedora Direct adapter 的自动化结果冒充完成。M5 的关闭口径仍只保留一条不可替代的实体 GUI 门：10 轮连续 Direct conversation，至少一轮实体麦克风全链路；没有可验证 sidecar/model/service 时保持文字优先和阶段未关闭。

### 5.6 批次 6（M5/M6）：PR #4 收口、回归门与移动性能证据

- **用户需求**：当前累计实现能被准确评审和稳定运行，文档、PR 描述、CI 与真实设备证据对应同一 commit，不把旧账单错误或外部 H1 阻断误写成当前 M5 失败。
- **当前问题**：PR #4 是从 M2 到 M6/H1/M5 的累计 54-commit、214-file Draft，不是单独的 M5 patch；当前 head `3f3a3c0` 的 Actions 两组 run 已全绿，PR body 的 billing/spending 与 “security workbench” 旧表述已不存在，但 body 仍保留“两个 run 刚入队、尚无结论”的旧 CI 描述，head/commit/file 数字与 CI 终态需与最新证据绑定。M5 的 Direct/实体语音门和 M6 的移动 120 Hz profile 仍未关闭。
- **实施范围**：批次 1–2 作为 PR #4 内 Direct LLM 正确性修复，避免为同一窄问题新开重复 PR；批次 3–5 仅在评审范围可承受且重新基线后加入，否则在 PR #4 合并后分批提交。刷新 PR 描述中的 commit、阶段、真实阻断和验收链接；对累计 diff 做一次按 M2–M6/H1/M5 边界的 review map。完成 voice/UI 改动后重跑 Fedora release、跨平台 build、Android 实机和 M6 120 Hz profile。
- **状态和数据语义**：每条证据绑定 exact commit、OS/device、服务版本和命令；GitHub check 的 `success`、本地 gate、live service 与人工 GUI 结果分栏记录。旧失败保留为历史，不覆盖最新结论；H1 的 external blocked 不改变 M5 数据终态或 CI 状态。
- **安全边界**：不为通过 PR 门而放宽 `uncertain`、approval、lease、credential 或 target binding；不把 synthetic audio 当 physical microphone；不在诊断 artifact 中保存正文、密钥或 raw recording。
- **主要影响模块**：`spec/`、PR #4 描述/检查、CI workflows、benchmark artifacts 和受批次 1–5 影响的 client tests；不借收口做无关重构。
- **自动化验收**：`npm run check`、固定 Flutter SDK `npm run flutter:check`、相关 PostgreSQL/transport tests、Linux release、自测、Android/Windows/Apple build，以及 `git diff --check`；所有结果绑定最终 head。
- **人工验收**：按批次 5 执行语音矩阵，并在具名 Android 设备运行实际 HomeScreen 120 Hz profile；reviewer 能从 PR 目录直接定位每个阶段的代码、测试和未关闭门。
- **外部依赖**：GitHub Actions 可用额度、实体 Android 设备及语音服务；Hermes 幂等提交不是 PR #4 的 M5 ready-for-review 前置条件，Connector 保持 fail closed 即可。
- **完成条件**：PR 描述不再把历史账单失败当当前状态；最新 head 的 CI、local gate 和人工证据无混用；Draft 的剩余理由只包含真实未完成门。是否合并/发布仍由用户授权，本文档不授权 push、PR 修改或 merge。

**2026-08-02 批次 6 收口进展**：事实核对完成（review map 草稿：`/tmp/voxhandoff-batch6-review-map.md`，按 M2–M6/H1/M5 边界归类全部 54 个提交）。PR #4 实际为 54 commits / 214 files、head `3f3a3c0`、Open/Draft/mergeable；当前 head 的两组 Actions run（[30706647988](https://github.com/Dreamy-MoLing/VoxHandoff/actions/runs/30706647988)、[30706647923](https://github.com/Dreamy-MoLing/VoxHandoff/actions/runs/30706647923)）均为 `completed/success`、各 5 jobs 全绿。本文件已同步修正：46/208 → 54/214；旧 CI `in_progress` → 当前 head 全绿；区分功能实现 head `ca6b794` 与 PR head `3f3a3c0`；PR body 旧 billing/security-workbench 表述已不存在，但仍保留旧的 pending CI 描述，待 Hermes 侧按本快照刷新 PR body。剩余未关：M5 连续 10 轮 GUI、实体麦克风全链路、正式 STT sidecar bundle、remote STT 契约、M6 移动 120 Hz profile；H1 保持上游阻断。

**2026-08-14 批次 6 收口状态更新**：PR #4 已于 2026-08-06 05:30 UTC 由
Dreamy-MoLing 合并（merge commit `e93fcee`，head 分支
`agent/m4-fairy-desktop`，60 commits，标题“归档：合并 VoxHandoff
M2–M6/H1/M5 最终快照”）。批次 6 的 PR 收口门已关闭；剩余未关仍是
M5 实体 GUI 门（连续 10 轮 Direct conversation + 至少一轮实体麦克风
全链路）、正式 STT sidecar bundle、M6 移动 120 Hz profile 与 H1 上游
阻断。2026-08-14 同时完成 M5 结构治理第 3–5 项拆分（gateway
postgres-ledger、node hermes-node-connector、client drift ledger 等，
见提交 dcf252d/3231082/26c9c7b），结构治理全部 5 项已闭环。

### 5.7 批次 7（H1）：Hermes 上游能力具备后的真实纵向验收

- **用户需求**：同一个人助手能够安全地把工作交给 Hermes，准确显示真实 session、工具、审批、lease、执行主机、完整回复和不确定状态。
- **当前问题**：Flutter → Gateway/PostgreSQL → Connector 的内部链路已实现，但 Hermes 0.19 未广告幂等 run capability，adapter 将缺失能力 fail closed 为 `idempotency=false`，生产 Connector 因此拒绝注册；approval resolution 还只有 FIFO `choice`，缺少不可变 approval ID。两者都是关闭完整 H1 所需的上游协议能力，不是 Direct LLM/M5 的完成条件。
- **实施范围**：上游首先提供可协商、可验证的 run idempotency key/查询语义；Connector 保持基于 capability 的 fail-closed 注册。由于 H1 原退出矩阵包含 approval，上游还必须提供不可变 approval identity 与按 ID resolve，再更新 adapter translation/fixtures。两项能力具备后，在隔离 profile 执行 Flutter、Gateway/PostgreSQL、Connector、Hermes 的 10 轮、stop、approval deny/approve、非优雅断线、Gateway/Connector 重启和 session resume。
- **状态和数据语义**：conversation route 继续以持久化 `(nodeId, agentId, capabilityRevision, sessionId)` 为唯一权威；非空 native session 在同一 `(nodeId, agentId, capabilityRevision)` 下只能绑定一个 conversation。accepted 后连接丢失保持 `uncertain`，只允许查询/恢复同一 request，不创建第二次 run。approval decision 绑定不可变 ID、operation hash、device signature、scope、lease、expiry 和 terminal CAS。
- **安全边界**：禁止通过版本号猜测能力、自动重提、FIFO 猜测、自动审批或跳过 lease 来通过 live gate；Hermes endpoint 仍只由出站 Node Connector 访问，不暴露未认证公网入口。
- **主要影响模块**：Hermes adapter、Node Connector capability/dispatch/approval translation、Gateway integration fixtures、isolated live PoC 与 H1 evidence；不改 Direct LLM 纯聊天语义。
- **自动化验收**：capability negotiation、相同 idempotency key 重放、accepted 后断线恢复、session route 冲突、并发 approval 精确寻址、迟到/重复 decision、lease 过期、Connector/Gateway restart 与日志脱敏 tests。
- **人工验收**：隔离 Hermes profile 上由用户观察并处理真实 approval，核对 UI execution host/session 与 ledger；故障注入后没有重复执行、串 session、静默完成或误报失败。
- **外部依赖**：Hermes 上游同时提供并广告幂等 run 语义与不可变 approval identity/resolution。若只补齐前者，可完成无 approval 的纵向子集，但不能关闭 H1。
- **完成条件**：H1 原退出矩阵在真实全链路通过，全部证据绑定 exact Hermes/Connector commit；任何必需 capability 缺失时 Connector 仍拒绝上线。

### 5.8 批次 8（M6）：移动端视觉基线复刻

- **用户需求**：移动端界面呈现冻结的星空视觉基线——深浅主题、平滑过渡、低文字密度、图形优先；待机/文字/录音/连接四态由真实状态驱动；桌面端视觉本轮不动。
- **当前问题**：`ui-prototype/` 已冻结为移动端视觉基线（星空色系 signal `#9fe7ff`、canvas `#070a10`、亮暗主题、球体 halo/orb/beam/glint 结构与四态交互），但 Flutter 客户端移动端仍是旧"夜航信号台" token（signal `#63F3E6`、ink `#05080F`）与传统 AppBar 布局，与冻结基线不一致。SignalCoreView 引擎（shader/painter 双实现、profile、reduced-motion、无障碍、真实电平驱动）是生产资产，本轮只对齐视觉形态，不重写。
- **实施范围**：在 `apps/client` presentation 层实现移动端视觉 Token（dark + light）与布局复刻：待机球体居中、文字态对话为主阅读区、录音态球心波形接真实电平、连接态光点/胶囊接真实 `connectionPhase`；设置页对齐主题/字号/背景入口。移动端与桌面端 token/布局采用按宽度隔离方案，桌面 golden 不得变化。背景导入按原型为视觉示例，不引入新持久化需求。
- **状态和数据语义**：本轮只改呈现，不新增协议、存储、领域模型或状态机语义；动效必须由真实状态（录音电平、TTS 播放包络、Agent 事件）驱动，不把原型 `setTimeout` 演示逻辑搬进生产。
- **安全边界**：不触碰 `lib/domain/`、`lib/application/` 语义；不新增依赖；无凭据、正文或录音外发；golden/accessibility/reduced-motion 门保持。
- **主要影响模块**：`apps/client/lib/presentation/design/agent_talk_theme.dart`、`signal_core_view.dart`、`home_screen*.dart`、设置页相关 widgets 与 `test/goldens/`；`ui-prototype/` 作为冻结基线只读不修改。
- **自动化验收**：`npm run flutter:check` 全绿；手机 golden 更新为复刻形态；桌面 golden 零变化（hash 对比）；accessibility 与 reduced-motion 测试保持通过。
- **人工验收**：手机窄屏观察四态（待机/文字/录音/连接）与设置页；桌面端视觉与行为与复刻前一致；录音态波形随真实麦克风电平变化，不依赖计时器模拟。
- **外部依赖**：无；桌面端是否跟进新基线待舰长另行沟通。
- **完成条件**：移动端呈现与冻结基线一致且由真实状态驱动；桌面端视觉与全部功能门无回退；提交为中文 conventional commits 且不 push。

**2026-08-15 批次 8 实现证据**：Codex 按任务书完成三个中文 conventional 提交——`5150c78`（feat: 增加移动端星空主题与视觉设置：mobile dark/light token、文字大小与主题持久化，背景入口保持视觉示例）、`0a9f48c`（feat: 复刻移动端星空交互壳层：窄屏待机/文字/录音/连接四态，接真实控制器状态与 SignalCore 移动绘制层，桌面路径保持原布局）、`8bab0d8`（test: 更新移动端视觉验收基线：主题设置/真实电平/交互断言，手机 golden 更新）。独立复验：pinned Flutter 3.44.6 `npm run flutter:check` 全绿（243 tests，2 个 live smoke 显式跳过）；桌面 4 个 golden 哈希与 Phase 0 基线逐字节一致（零变化）；`git diff 6690b6b..HEAD` 仅含 presentation/test 与 phone goldens，未触碰 ui-prototype/domain/application/pubspec/workflow；生产代码无 `setTimeout`。未 push、未触发 CI。

**2026-08-15 批次 8 修缮证据（WebView 回退 + 逐项对齐）**：Codex 曾以 `9a8fff1`（feat: 以原型 WebView 驱动移动端主页面）把原型 HTML 纳入 Flutter assets 并用 webview_flutter 套壳，但真机 `<script type="module">` 在本地 asset 加载下被 CORS 拦截、交互全断，桌面 Linux 亦不走 WebView 路径，属偏离"SignalCoreView 生产资产 + presentation 层复刻"的无效方案。由协调者回退并交 Codex 逐项修缮：`e920f3b`（revert: 回退原型 WebView 驱动方案：移除 assets/mobile_ui、mobile_webview_home_screen、webview 依赖，移动端恢复原生实现）、`a64203b`（fix: 历史待机视觉修缮，曾使用 `min(58vw,230px)`；该旧数值已由最终 cascade 契约修订为 `min(92vw,370px)`）、`7c0885e`（fix: 历史文字态视觉修缮，曾使用 `min(84vw,320px)`；该旧数值已由最终 cascade 契约修订为 `min(112vw,460px)` 并保留 `bottom:-250px`）、`ba891a8`（fix: 对齐移动端录音态范本：保留 18 根波形接真实 audioLevel、两级 warm/strong glow、移除旧 mic 叠层）、`7d629a5`（fix: 对齐移动端连接状态范本：已连接绿色光点、异常常驻胶囊、connected 切换后 3 秒提示）、`c7190d1`/`8612939`（fix: 对齐移动端设置页范本：全屏设置视图 + 主题/背景/字号三行）、`773062a`（fix: 对齐文字态核心裁切与手机基线）、`2b17bc9`（docs: 记录移动端 UI 打磨计划）。独立复验：pinned Flutter 3.44.6 `npm run flutter:check` 全绿（244 tests，2 个 live smoke 显式跳过）；桌面 4 个 golden 与 `9a8fff1^` 基线逐字节一致；`ui-prototype/` 零改动、pubspec 无新增依赖、生产代码无 `setTimeout`/`setInterval`；真机（vivo V2359A）实拍待机态（58% 居中核心 + 断裂 halo/光束/glint + 无顶栏胶囊 + 星空）与文字态（84% 沉底裁切 + 气泡阅读区 + 连接点/设置图标 + composer）达标，录音态/已连接态 golden 达标；录音态真机进入 failed 为本地 STT sidecar 未启动的运行时依赖（`stt_warmup_failed`），非视觉缺陷。未 push、未触发 CI。

**2026-08-15 批次 8 文字态二次修缮证据**：舰长真机验收发现文字态仍不符合范本（中部为裸文本"暂无对话。"、composer 大输入框挤压光球），resume Codex 会话修复：`0059421`（fix: 对齐移动端空态对话气泡：空态由裸文本改为范本 quiet 气泡"我已准备好，随时可以开始。"，复用 MobileConversationBubble）、`e5f137d`（fix: 收敛移动端文字态 composer：面板透明度 0.84→0.42、padding 收敛、按钮 30px 透明化，保留编辑/确认/发送产品功能）、`ca56c71`（fix: 对齐移动端连接状态胶囊：按范本校准异常胶囊尺寸/透明度/边线/阴影，顶部设置与已连接光点收敛 28px）、`28f6376`（fix: 补齐移动端气泡组件 key）。独立复验：`flutter:check` 全绿（244 tests + 2 live smoke skip）；桌面 4 golden 与 `9a8fff1^` 基线逐字节一致；ui-prototype 零改动、无新增依赖、生产代码无 setTimeout；真机（vivo V2359A）实拍文字态确认：空态显示范本 quiet 气泡、composer 收敛透明、光球沉底裁切、顶部异常胶囊符合范本。未 push、未触发 CI。

**2026-08-15 批次 8 第三轮契约复刻证据**：严格按任务书 Phase 0–4 完成最终 CSS cascade 核对、显式 540ms pointer/timer 手势状态机、文字态长按上下文保持与手机视觉校准。390×844 的待机核心为 `min(92vw,370px)=358.8px`；文字/录音核心为 `min(112vw,460px)=436.8px`，文字态使用 `bottom:-250px` 并通过 `OverflowBox` 保持水平溢出和底部裁切；halo/orb/beam/glint、18 根真实 audioLevel 波形、conversation、composer、connection capsule、settings 均按最终矩阵修订。新增 14 项 fake-time widget regression 全部通过；完整 pinned Flutter 3.44.6 gate 为 `258 passed, 2 skipped`，skip 为显式 live smoke。phone golden 更新范围仅为 `connected_workspace_phone.png`、`m4_recording_phone.png`、`m4_uncertain_phone.png`、`unpaired_phone.png`；四张 desktop golden 的 SHA-256 与 Git blob hash 均与更新前一致。`ui-prototype/`、pubspec、domain/application 均无本轮变化，未新增依赖、未引入 WebView 或原型计时器。当前环境 `adb devices -l` 未发现 vivo V2359A，`flutter devices` 仅发现 Linux/Chrome，故真机人工验收 gate 标记 blocked，golden 不作为真机交互证据。未 push、未触发 CI。

### 5.9 仍需产品确认、但不阻断批次 1–2 的事项

以下事项采用保守默认值继续开发；只有用户明确改变默认值时才需要先改规格：

1. **Hermes 是否接收个人记忆与人格提示**：默认不接收；统一助手只统一展示和本地偏好，Hermes 保持其原生 Agent 配置。若未来允许，必须逐项预览并显式授权。
2. **首版助手数量**：默认只支持一个 active AssistantProfile，但数据模型保留 `assistantId`；多助手管理不是 M5 发布门。
3. **跨 Provider 历史迁移**：默认空白新 conversation；旧历史只展示/导出/删除。若允许迁移，优先复制用户选中的摘要而不是整段原文，并在发送前预览。
4. **免手连续监听**：默认关闭，M5 先保证显式录音和手动打断可靠；是否默认启用 VAD/唤醒词以及采用何种本地模型，需要后续单独的隐私、功耗和误触发决策。
5. **PR #4 的 ready-for-review 设备门**：基线要求 10 轮连续 GUI Direct conversation，其中至少一轮完成 Fedora 实体麦克风全链路；Android 120 Hz 与移动 remote STT 是 M6/移动发布门。若用户要求 PR #4 同时代表全平台发布候选，则必须把两项也设为 Draft 阻断。
6. **“security workbench” 是否成为产品需求**：默认从 PR #4 的阶段门删除，因为当前 `spec/` 没有该用户需求、状态语义或验收条件；若用户希望保留，必须先定义范围并放入既有 M5/M6 内部批次，不能仅凭 PR 文案扩展产品。

## 6. 测试矩阵

### 6.1 每次变更

- formatting/lint/type check；
- Core 和 adapter unit tests；
- Protobuf lint/generation/breaking check；
- 数据 migration 和 adapter contract tests；
- secret fixture 与日志脱敏测试。

### 6.2 合并前

- 相关 integration/failure injection；
- 旧版本数据库/协议兼容；
- 断线、乱序、重复、超时、取消和 uncertain；
- UI golden/accessibility tests；
- 依赖/许可证变更说明。

### 6.3 Nightly/设备实验室

- Android、iOS、macOS、Windows build + smoke；
- 真实安全存储写入/重启/读回/撤销；
- 麦克风权限、设备断开和音频播放中断；
- PostgreSQL/Drift/Gateway 重启和升级；启用 PowerSync 后再加入其退出/恢复矩阵；
- Hermes 允许版本的 live compatibility；
- 性能、内存、GPU、冷/热 STT/TTS 指标。

### 6.4 发布门

- 所有非协商安全测试通过；
- 无已知 Critical/High 可利用漏洞；
- SBOM 和第三方许可证清单完成；
- Gateway 数据备份和恢复演练通过；
- 设备凭据吊销后旧设备不可继续连接；
- TLS 错误 fail closed；
- 50 次端到端和 Hermes 同一 session 10 轮验收通过；
- 安装、升级、卸载不删除未明确选择删除的用户数据。

### 6.5 可重复性能口径

- 每份结果记录 exact OS/build、CPU/GPU/RAM、设备型号、电源模式、组件版本、冷/热状态和网络 profile；“中档设备”在 M3/M4 gate 前必须替换为至少一台具名 Android 参考设备，不能仅凭开发机推断；
- local profile：RTT ≤ 2 ms、无人工丢包；normal remote profile：RTT 80 ms、jitter 20 ms、loss 0.5%、下行 20 Mbps、上行 5 Mbps；degraded profile：RTT 250 ms、jitter 50 ms、loss 2%；
- stage latency 的 P50/P95 至少采集 50 个成功样本，先做 5 次不计入的 warmup；cold start 另采至少 10 次并单独报告，不与 warm 数据合并；
- 50 次端到端成功率把 Client/Gateway/adapter/STT/TTS 导致的失败计入，把用户拒绝审批和 Agent 明确业务失败单列，不能从分母删除超时；
- 同进程阶段使用 monotonic clock；跨进程通过 trace ID 记录各自 monotonic duration，不用未校时的 wall clock 直接相减；
- 所有基准保存脱敏原始测量、汇总脚本和 pass/fail 结论；变更目标必须先修改 `PRODUCT.md` 并说明实测依据。

## 7. PoC 规范

PoC 是验收工具，不是一次性脚本。每次 live PoC 记录：

- OS、硬件、Agent/adapter/model 版本；
- 冷/热状态和网络环境；
- request/thread/turn 的脱敏关联；
- 每阶段开始/结束/耗时；
- 成功、失败、取消、uncertain；
- 日志中无秘密的证明；
- 与 gate 的明确通过/失败结论。

Live PoC 不得自动执行写文件、发消息、发布、删除或管理员动作。需要审批的测试使用临时目录、无害命令和明确人工批准。

## 8. 当前命令

```bash
npm install
npm run check
npm test
npm run protocol:generate
npm run protocol:breaking
npm run protocol:check:dart
AGENT_TALK_POSTGRES_URL=<isolated-loopback-url> npm run test:postgres
AGENT_TALK_LOOPBACK_INTEGRATION=1 npm run test:transport
npm run flutter:check
VOXHANDOFF_SECURE_STORAGE_SELF_TEST=1 \
  ./apps/client/build/linux/x64/release/bundle/agent_talk_client
VOXHANDOFF_M4_RENDER_BENCHMARK=1 \
  ./apps/client/build/linux/x64/release/bundle/agent_talk_client \
  > /tmp/voxhandoff-m4-measurements.jsonl
npm run benchmark:m4:summary -- \
  /tmp/voxhandoff-m4-measurements.jsonl
flutter run --profile -d <android-device-serial> \
  --dart-define=VOXHANDOFF_M4_RENDER_BENCHMARK=true \
  2>&1 | tee /tmp/voxhandoff-m4-android-profile.log
npm run benchmark:m4:summary -- \
  /tmp/voxhandoff-m4-android-profile.log
VOXHANDOFF_MVP_RENDER_BENCHMARK=1 \
  ./apps/client/build/linux/x64/release/bundle/agent_talk_client \
  > /tmp/voxhandoff-mvp-home-measurements.jsonl
npm run benchmark:mvp:summary -- \
  /tmp/voxhandoff-mvp-home-measurements.jsonl
npm run poc -- doctor
```

显式 live PoC：

```bash
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
  --approval-probe \
  --approval-timeout-seconds 60 \
  --approval-decision deny
npm run poc -- hermes \
  --base-url http://127.0.0.1:18642 \
  --token-env HERMES_API_KEY \
  --prompt "Use the terminal tool to run sleep 30, then reply: finished." \
  --disconnect-probe
```

`--disconnect-probe` 只在隔离 gateway 中使用：先从独占 loopback 端口精确解析临时 PID，观察到 `tool.started` 后终止该 PID。禁止用进程名、宽泛 PID 匹配或默认 gateway 做故障注入。

新工作区加入 Flutter、Buf、PostgreSQL 等工具后，在这里添加统一命令，不把关键检查藏在个人 IDE task 中。

## 9. 可观测性

每个请求至少记录：

- connection/conversation/request 的不可逆或本地 opaque ID；
- stage 与 duration；
- Agent/adapter/protocol version；
- accepted、first event、first stable sentence、first audio、completed；
- retry decision、sequence gap 和 failure code；
- 不记录默认正文、原始音频、认证头或密钥。

UI 不展示虚构完成百分比。诊断页面显示最后真实事件、同步状态、实际执行主机和是否可能仍在远端运行。

## 10. 风险登记

| 风险 | 当前处置 | 触发动作 |
| --- | --- | --- |
| Embedded 与同步模式语义分叉 | 两种账本实现共享 request/sequence/idempotency 契约 | 同一 failure fixture 结果不同即阻止 M1/M2 |
| 设备配对或撤销失效 | 单 owner、本机 bootstrap、短期 token、轮换和逐流撤销检查 | 未授权设备可建流或撤销后仍可操作即阻止发布 |
| approval 并发或迟到响应 | 耐久状态机、CAS、lease/scope 和 idempotency | 任一重复/迟到批准到达 Agent 即 Critical |
| Client 离线命令自动执行 | Client 只保存草稿，恢复连接必须重新确认 | 任何自动排空可执行命令即阻止发布 |
| protocol 滚动升级不兼容 | major/minor handshake、前一 minor fixtures、expand-first migration | N/N-1 组合失败即阻止升级 |
| Direct Provider 凭据或历史串用 | 不可变 Profile identity、独立 revision/conversation、legacy 历史隔离、确认目标快照 | 旧 key/历史到达新 origin 或确认后可换目标即阻止 M5/发布 |
| Direct request/终态竞争 | request-scoped owner、cancel-and-wait、互斥 terminal、有界 body、generation gate | 迟到流污染新会话、残缺回复标 completed 或隐藏 TTS 即阻止 M5 |
| 个人记忆跨 backend 泄露 | local-only 默认、可见 scope、上下文预算、显式迁移；默认不注入 Hermes | 已删除/未授权记忆或跨 Provider 摘要进入请求即 High |
| 远程 STT 泄露音频 | 默认关闭、provider 同意、目标/TLS/保留提示 | 未确认上传或目标变化后继续上传即 Critical |
| 本地 STT 隐式下载模型 | bundled executable + 用户选择的 canonical local model path；禁网缺失时 fail closed | production 启动因模型名访问网络即 High/发布阻断 |
| 远程 TTS 泄露回复正文 | exact-origin 同意、TLS/保留变化重确认、只发送允许播报文本 | 未确认把回复/秘密/审批正文发送给远端即 High |
| Hermes capability 或 SSE 契约变化 | fail-closed 协商、稳定事件身份、fake 契约与隔离 live profile | 任一必需能力缺失或事件不可恢复即拒绝 Connector 上线 |
| Hermes 当前纵向真链路未验证 | fake Hermes + 真实 Gateway stream 已覆盖 Connector 边界，不擅自复用默认 gateway | Hermes 同时补齐幂等 run 与精确 approval identity/resolution 后关闭完整 H1 live gate |
| PowerSync 引入第二同步/授权平面 | 当前采用 Drift + 已认证 cursor sync；PowerSync 仅位于可选 Sync Adapter | 只有许可、运维、最小授权和量化收益同时过门才引入 |
| 支持客户端平台插件能力不一致 | record/media/security adapter + real device tests | 单平台失败显式降级或写原生 plugin |
| TTS 冷启动/崩溃 | 常驻预热、分段、纯文字降级 | 不达标时限制自动播报长度 |
| adapter 证据被误作 GUI/发布证据 | 独立证据轴分栏、exact commit/device/service 记录 | synthetic/service smoke 被写成实体麦克风或发布通过即退回验收 |
| STT 技术词误识别 | 默认确认、高风险审批独立 | 30 条基准不达标切换后端 |
| 多设备重复提交 | DB uniqueness、idempotency、lease、uncertain | 任何重复执行为发布阻断 |
| 视觉模板化或近似第三方资产 | 原创视觉主命题、语义 token、组件状态目录、golden 和许可证记录 | 出现禁止的泛 AI 模板或无来源资产即退回设计门 |
| 视觉耗电或不可访问 | 档位、减少动态、静态回退 | 中档设备不达标降低 shader 复杂度 |
| 远程高权限泄露 | device scope、TLS、Node 出站、Agent loopback | 安全门失败停止远程发布 |

## 11. Definition of Done

一项变更只有在以下条件全部满足时完成：

- 行为已在正式规格中存在，或规格随变更更新；
- 类型、lint、相关 unit/integration/contract test 通过；
- 错误能定位到具体 stage；
- 失败、取消和 uncertain 语义没有合并；
- Direct LLM 的 `completed/cancelled/failed/incomplete/truncated`、请求 owner 和有界读取经过相应 failure fixtures；
- 发送前确认绑定精确 backend target；Profile、conversation、route 或执行主机变化会撤销确认；
- 不引入明文秘密、静默重试或自动审批；
- Android、iOS、macOS、Windows 影响和降级路径已评估；
- 新依赖的维护、许可证、体积和退出路径已记录；
- 用户可见变化有可访问性和无动画路径；
- 必要的 migration、protocol compatibility、回滚和诊断信息可用；
- 自动化、真实服务、人工 GUI/实体设备和发布证据按层次记录，并绑定 exact commit；
- 改动形成聚焦、说明清楚且工作树干净的本地提交；远程写入仍按授权执行。

**2026-08-13 Android remote STT configuration evidence（本轮）**：已启动实体
`V2359A` 上的 profile APK，在 Voice settings 选择 `Consented HTTPS provider
(Android)`，填写真实 Tailscale origin `https://100.103.253.87`、provider ID
`voxhandoff-stt`、TLS/retention/revision disclosure，并从独立临时 token 文件
输入 64 位测试 token。UI 实测显示所有字段值和 token 掩码；consent 复选框仍为
`checked=false`，未保存、未上传音频、未执行 readiness，因此本阶段只证明真实
配置表单已到人工同意门。当前实现的 readiness 需要先保存带 `consentedAt` 的配置，
不能在未同意状态下用 Disabled 或 fake 结果代替。下一阶段等待用户/布洛妮娅勾选
当前 disclosure 并保存后继续。

**2026-08-13 Android remote STT readiness evidence（本轮后续）**：重新打开 Voice
settings 后，真实设备 UI 回显 origin/provider/disclosure，consent 为
`checked=true`，且 Save/Test 按钮 enabled，证明设置 round-trip 已完成；UI 未展示
原始 `consentedAt` 时间戳，未从 secure storage 导出秘密或时间戳。点击真实
`Test STT readiness` 两次均得到 `The local STT service could not be reached.`。
STT 服务日志在对应时间没有新增 Android `/v1/health` HTTP 记录；设备对
`100.103.253.87` 的 ICMP 可达，宿主机使用测试 CA 的独立 HTTPS health check 仍为
`status=ready`。因此本阶段真实结论是 Android Dart HTTPS/TLS 信任路径未闭合，
不是 provider readiness 已通过；未触发 `RECORD_AUDIO`（设备权限仍为
`granted=false`），未录音、未上传、未生成中文转写或确认终稿，也未执行断网恢复。
继续前需修复/明确 Dart 客户端的显式 CA 信任输入，保持证书链、SAN、TLS 校验和
无明文/无 `onBadCertificate` 约束。

**2026-08-13 Android fresh-process readiness follow-up**：owner 确认 D-024 profile
安装后，实体设备新进程重新打开设置，provider/origin/disclosure 回显，consent 为
`checked=true`，token 不回填明文；点击 readiness 仍显示
`The local STT service could not be reached.`，STT 服务无对应新 `/v1/health` 请求。
设备 Tailscale ICMP 可达，宿主机 Dart `SecurityContext` 使用同一测试 CA 的 health
请求为 HTTP `200`。应用加密存储中 profile/token 记录存在，但未读取或输出任何
解密内容。

针对 Android engine 的组合信任行为，新增变体在显式 CA 存在时使用
`SecurityContext(withTrustedRoots: false)` 仅信任导入 CA，并显式设置 TLS 1.2 最低
版本；无自定义 CA 时仍使用平台系统根。定向测试 7 项、Flutter analyze 均通过。
新 APK 已完成构建和无线传输，但设备再次停在 Android
`PackageInterceptActivity`，人工确认未代点；因此该变体尚未取得新的 Android
readiness 证据。麦克风、中文录音/转写/终稿确认和断网恢复继续保持未执行。

**2026-08-13 Android installation retry evidence**：再次执行窄信任集 profile APK 的
`adb -s 100.96.66.108:5555 install --no-streaming -r -d`，APK SHA-256 为
`a124008c8ec2fd288f4add546013e2126ce46430c15776f6f87d2acdfa6d2463`，文件传输约
`38.3 MB/s`，命令最终返回 `Success`，包 `lastUpdateTime` 已更新。此次等待期间
没有观察到 `PackageInterceptActivity`，前台为系统 Launcher，所以没有 owner 点击
安装确认的实机交互证据。按安全边界未启动应用、未执行 readiness、未触发麦克风或
上传音频；继续等待 owner 明确确认后再进入下一阶段。

**2026-08-13 Android remote STT explicit CA repair evidence**：针对 D-023，Dart
`JsonHttpRemoteSttTransport` 现在在收到已导入的配对 CA 时创建
`SecurityContext(withTrustedRoots: true)`，调用 `setTrustedCertificatesBytes`
后再创建标准 `HttpClient`；生产 voice factory 复用
`SecureGatewayConnectionProfileStore` 中的 trusted roots。没有加入
`onBadCertificate`、明文 HTTP 或 hostname 校验旁路。有效测试 CA 注入、malformed
CA 拒绝、remote STT 和 production voice flow 共 7 项定向测试通过，Flutter
analyze 无问题。

随后构建 profile APK 成功，SHA-256 为
`efdad4e400d09bc32778222065b27e2d3bcfb8b9f3cc56a49f04d641e2cac9f8`。指定设备的
`adb -s 100.96.66.108:5555 install --no-streaming -r -d` 已完成文件传输，但设备
前台实际停在 Android `PackageInterceptActivity` 安装确认页，安装结果尚未返回。
因此本阶段尚未重新启动应用或执行 readiness；等待用户确认安装后继续，不能把构建
或传输结果写成 Android readiness 通过。

**2026-08-13 Android remote STT live acceptance evidence（窄信任集变体）**：owner
确认 APK 已安装后，实体 `V2359A` 新进程启动成功。Voice settings 回显
`Consented HTTPS provider (Android)`、`voxhandoff-stt`、`https://100.103.253.87`、
`zh` 及 TLS/retention/revision 声明；token 仍为空掩码，consent 为 `checked=true`。

隔离 STT 已改用与手机 Gateway profile 相同的 Tailscale SAN CA；手机 readiness
真实请求到达 provider，UI 曾显示 `Ready`，服务日志有 `/v1/health` `200`。这项证据
确认 Dart 显式 CA、`withTrustedRoots:false`、TLS 1.2 和 hostname/SAN 校验链路已通，
没有使用 `onBadCertificate` 或明文。

录音控件真实进入 `Recording · speech remains editable before send`，没有出现麦克风
权限弹窗；ADB 包状态显示 `RECORD_AUDIO: granted=true`。停止后真实手机请求抵达
`/v1/transcribe`，服务返回 `422`，安全诊断记录 `stt_no_audio`。UI 最终显示
`Remote speech recognition failed. No Agent request was sent.`，Editable draft 为空，
Confirm disabled。该阶段没有有效中文转写、可编辑终稿、确认动作或中文识别质量证据，
也没有用 fake 音频/文本补齐。

网络恢复子检查中，唯一的 Tailscale TCP Serve 路由被 `tailscale serve reset` 移除，
状态为 `No serve config`，之后恢复为 `443 -> 127.0.0.1:18654`；恢复后服务端连续
收到 readiness `GET` 并返回 `200`。断路期间手机端 readiness 的超时文案因请求尚在
30 秒窗口内未单独采集，故只记 provider-route 恢复部分通过，完整离线恢复仍待有效
录音成功后复验。

当前阶段结论：Android TLS/readiness 通过；真实麦克风音频门阻塞 STT 转写/终稿确认。
Hermes 零改动，未 push，未自动审批，设备只使用
`100.96.66.108:5555` Tailscale ADB。

**2026-08-13 Android remote STT final audio retry**：重新启动已安装 APK，确认隔离
STT 与 Tailscale `443 -> 127.0.0.1:18654` 存活；点击录音后 UI 进入
`Recording · speech remains editable before send`，等待约 8 秒覆盖外放窗口并停止。
手机真实请求抵达 `/v1/transcribe`，服务返回 `422`，安全错误码为
`stt_no_audio`。UI 显示 `Remote speech recognition failed. No Agent request was sent.`，
Editable draft 为空、Confirm disabled。

最终轮仍未取得有效中文转写、可编辑终稿、确认或完整断网恢复证据。当前阻塞已收敛到
手机麦克风实际输入电平/音频路由，不能继续归因于 TLS、CA、SAN、token 或 readiness；
下一步应先独立验证 Android 录音输入电平，再重跑验收。Hermes 零改动，未 push，未
自动审批，设备只经 `100.96.66.108:5555` Tailscale ADB。

**2026-08-14 真机验收证据（新 APK / 新 STT 服务，本轮）**：按任务书重建隔离
STT HTTPS 服务。证书 SAN 为 `xiaoxin-fedora.tailbd75d3.ts.net`、
`100.103.253.87`、`100.96.66.108`，有效期为 2026-08-14 至 2026-09-13；宿主机
`curl -sk --cacert <new-ca> https://127.0.0.1:18654/v1/health` 返回 HTTP `200`、
`status=ready`、`backend=faster-whisper`、`model=faster-whisper-base`；
`tailscale serve status` 确认 `443 -> 127.0.0.1:18654`。服务日志为
`voxhandoff-stt-https listening on 127.0.0.1:18654` 和 health `200`。CA/服务证书
SHA-256 分别为 `cc586327c1322f35a3b82883df92568e23e378605530ee61d1222eeed4b0d543`
和 `f74faf4be23215dbc336f8b339a053b81c5608ec12f9a81aed3cb1b6d1f29c40`；token 和
私钥未写入本文件。阶段日志：`/tmp/voxhandoff-acceptance-20260814.log`。

构建命令 `flutter build apk --debug` 首次因当前 PATH 无 `flutter` 返回退出码 `127`；
使用已存在的 `/home/roco/develop/flutter-3.44.6/bin/flutter build apk --debug` 重跑
成功，Flutter `3.44.6`，APK 为
`apps/client/build/outputs/flutter-apk/app-debug.apk`，版本 `0.1.0+1`、Debug，
SHA-256 为
`779e1c89ccbd806bf6b55a99a5fa8b7ebcff9bc399508d6ea0bf88fa7dee360e`。
`adb -s 100.96.66.108:5555 install --no-streaming -r -d` 返回 `Success`；包
`dev.agenttalk.agent_talk_client` 的 `lastUpdateTime=2026-08-14 08:48:23`、
`versionCode=1`、`versionName=0.1.0`、`DEBUGGABLE`。未出现
`PackageInterceptActivity`，未代点安装确认。

应用启动后，Voice settings UI 回显 HTTPS STT、provider ID `voxhandoff-stt`、
origin `https://100.103.253.87`、语言 `zh`，consent 为 `checked=true`；新 token
已通过密码字段保存，未回显或写入日志。点击 `Test STT readiness` 后 UI 真实显示
`The local STT service could not be reached.`；对应服务日志没有新增 Android
`/v1/health`，宿主机独立 health 仍为 HTTP `200`。`RECORD_AUDIO` 实际权限为
`granted=true`。

本轮未开始录音：现有旧 Gateway profile 仍处于 paired 状态，应用只显示
`Connect Gateway`；Private CA 证书选择器只存在于 Gateway pairing 面板，当前流程
没有“重新配对/编辑证书”入口。未清除应用数据、未绕过 secure storage、未使用假音频
或假文本。因此没有可记录的 `bytes/rms`、中文转写、Editable draft 或 Confirm
证据，任务停在手机重新导入新 CA 后的 readiness 门。下一步需通过现有 pairing UI
重新导入 CA 并完成其必要的人工 owner 门，再重启 app、重测 readiness，之后才能做
外放录音和终稿确认。Hermes 零改动、未 push。

**2026-08-14 CA 重新导入入口与第二轮真机证据**：新增入口位于 Voice settings 的
Hermes 区域，已配对设备可直接走 `Re-import trusted CA`。流程复用现有 Private CA
选择器和 PEM/私钥/大小校验，保留原 Gateway audience，仅在 profile 校验通过后把新
CA 写回 secure storage；未增加 `onBadCertificate`、明文 HTTP 或测试 CA 路径。生产
remote STT transport 在新请求创建时读取当前 Gateway profile 的 trusted roots，避免
启动时旧 CA 快照继续生效。新增导入服务、动态 trust-root 测试和 Voice settings 入口
测试；Dart format、Flutter analyze 均通过，定向 13 项和全客户端 232 项通过，2 项
预置 live smoke 按条件跳过。

使用 `/home/roco/develop/flutter-3.44.6/bin/flutter build apk --debug --no-pub` 构建
Debug APK，版本 `0.1.0+1`，SHA-256 为
`2565abe515b5b1bae3f921bf5f52a3f206090159596274b2f948138c292f1309`。通过
`adb -s 100.96.66.108:5555 install --no-streaming -r -d` 安装成功，包
`lastUpdateTime=2026-08-14 09:03:29`，没有代点系统安装确认。

实机 UI 通过 ADB 注入新 CA 后显示 `Trusted CA imported. Test STT readiness again.`；
点击 `Test STT readiness` 后显示 `Ready`，服务日志有 4 行
`stt_http "GET /v1/health HTTP/1.1" 200 -`。随后按任务书只做一次外放录音：UI 进入
Recording，停止后显示 `Remote speech recognition failed. No Agent request was sent.`；
服务端收到 `stt_http "POST /v1/transcribe HTTP/1.1" 401 -`，未进入音频解析，因而没有
`stt_audio_stats`、bytes/rms、中文转写、Editable draft 或 Confirm 证据。未重录；任务
当前阻塞在 STT token 与服务端期望值不一致或为空的认证门，不能把它写成音频成功。
阶段日志：`/tmp/voxhandoff-acceptance-20260814.log`。Hermes 零改动，未 push。

**D-031：2026-08-14 第三轮 token 对齐与唯一录音结果**：从服务端受保护 env 文件读取
provider token；手机 Voice settings 中清空密码字段后逐字符重新输入并保存，未清除
应用数据，token 值未进入日志、文档或报告。UI `Test STT readiness` 显示 `Ready`，
服务端 `stt.log` 新增 `stt_http "GET /v1/health HTTP/1.1" 200 -`（line 10）。

按任务书只触发一次真实录音，立即写入阶段日志并等待外放约 8 秒；停止转写后 UI 显示
`Remote speech recognition failed. No Agent request was sent.`。服务端新增
`stt_http "POST /v1/transcribe HTTP/1.1" 401 -`（line 11），认证在音频解析前失败，
没有 `stt_audio_stats`，所以 bytes/rms 不可得；没有中文转写、Editable draft 或
Confirm 证据。按硬边界未重录、未伪造证据。结论：本轮 STT token 验收仍未通过，需由
owner 后续核对 provider credential 传递链路后再开新一轮；本轮不再操作。阶段日志：
`/tmp/voxhandoff-acceptance-20260814.log`。Hermes 零改动，未 push。

## D-034 / 2026-08-14 第六轮 AudioRecord source/read-mode 对照

- 源码核对：当前 `READ_SIZE=3200`，`AudioRecord` 缓冲区至少 `6400` 字节。官方
  文档说明 `READ_NON_BLOCKING` 无可读数据时可以立即返回 0，返回值也可以是 0 或
  正数；没有证据表明本缓冲区配置会让非阻塞读取永久为 0。
- 实验 A：`VOICE_RECOGNITION(6) + READ_NON_BLOCKING`。APK SHA-256 为
  `cef0271a1398889b3fc99b6660c55d5d5758afeccc83cf2f8dcf96b01f6d58ca`，安装时间
  `2026-08-14 10:09:30`。原生日志选中 `source=6`，约 40 秒退出为
  `reads=1983 zeroReads=3795`，`sinkNull=false`，诊断中有 `push success bytes=640`；
  UI 失败，服务端对应 POST 422，`stt_audio_stats bytes=0 rms=0.00`，无文本、draft
  或 Confirm。
- 实验 B：`VOICE_RECOGNITION(6) + READ_BLOCKING`。APK SHA-256 为
  `92bfb4a082ed3e46aea318da684d3d7468b9dae97fa4b05b946458ed6c35443e`，安装时间
  `2026-08-14 10:14:17`。原生日志约 40 秒退出为 `reads=391 zeroReads=0`，每次
  `readCount=3200`，heartbeat 的 `idleMs` 约 100，`sinkNull=false`，stop 与 join
  均成功；服务端对应 `stt_audio_stats bytes=0 rms=0.00`、422 `stt_no_audio`，UI
  仍为 `Remote speech recognition failed. No Agent request was sent.`，无中文转写、
  draft 或 Confirm。
- 结论：本轮新鲜原生日志没有重现“source 或 read mode 导致 read=0”。两种组合都
  能读到正数并调用 EventSink；`bytes=0` 出现在 native EventSink 之后的端到端路径，
  当前不足以安全归因到 Dart EventChannel 消费或 STT 缓冲的具体一行代码。保留 B
  作为 native 侧最优组合：VOICE_RECOGNITION 优先、READ_BLOCKING、现有 heartbeat
  和 stop/join 超时保护。端到端语音验收仍未关闭。
- 边界：本轮最多两次录音已用完；没有第三次录音、伪造文本或 Confirm。Hermes 零改动，
  设备只经 `100.96.66.108:5555` Tailscale ADB，未 push。阶段日志为
  `/tmp/voxhandoff-acceptance-20260814.log`。

## 12. Stacked PR 分层协作规范（2026-08-15 启用）

> 背景：AI 编码代理（Codex）默认把整个功能塞进一个巨型 PR，导致难审、难合、
> reviewer 上下文丢失、反馈质量下降。GitHub 官方方案是 stacked PR：按依赖链把
> 功能拆成有序小 PR，每层一个关注点，CI 逐层评估。参考
> https://github.blog/engineering/turn-one-giant-ai-generated-pull-request-to-a-reviewable-stack/

### 12.1 分层原则

- 一次功能实现必须拆层，禁止让 Codex 一次提交覆盖跨域大 PR。
- 典型分层（按依赖自下而上）：**数据层 → API 层 → 接线层 → UI 层**。
- 每层只关心一个关注点，小到 reviewer 能一次拿住；依赖关系自然从下层 PR 流入。
- 每层一个分支、一个 PR、一组对应测试；上层分支基于下层分支，不直接基于 `main`。
- 对应我们的 Codex 工作流：任务书按层编写，每层独立派发、独立验收、独立写
  DELIVERY 证据，验收通过才进入下一层。

### 12.2 gh-stack 命令

```bash
# 一次性安装
gh extension install github/gh-stack
gh skill install github/gh-stack

# 日常使用
gh stack init                 # 以 main 为基底开新栈
gh stack add <branch>         # 在当前栈顶加一层
gh stack push                 # 推送全部层分支
gh stack submit               # 为每层创建/更新 PR
gh stack rebase               # 本地级联 rebase（比 Web 端 Rebase 按钮安全，保留签名提交）
gh stack sync                 # 拉取远端、级联 rebase、推送、同步 PR 状态
gh stack checkout <stack|PR>  # 切换栈/PR
gh stack view                 # 查看当前栈
```

- 审阅顺序：**自上而下读**（先看顶层 PR 理解最终目标），**自下而上审**（从底层依赖逐层验证）。
- 注意：Web 端「Rebase stack」按钮在 GitHub 服务器上执行，会重置 committer 且不保留
  签名提交；分支保护要求签名时使用 `gh stack rebase` 本地执行。

### 12.3 当前约定

- 本仓库执行 Android-first MVP，尚未进入大规模栈协作；本节作为规范先行登记，
  从下一批跨域功能（数据+API+接线+UI 同时改动）开始强制启用。
- 分层提交仍然遵守 3.6 的 Git 治理：中文 conventional commits、一个提交一个逻辑
  变化、push/PR 前有明确授权。
