# VoxHandoff 软件验收报告

## 1. 验收结论

**最终结论：FAIL**

当前版本的离线质量门、Node/Gateway 构建、真实 loopback HTTP/2/TLS 边界以及同源码树的跨平台 CI 构建均通过；但是生产 Node → Gateway 长连接使用 `defaultTimeoutMs: 30_000`，本次以真实 HTTP/2 Gateway 和生产同参数 transport 实测后，在 **30,018 ms** 稳定触发 `deadline_exceeded` 并断流。`HermesNodeConnector.run()` 没有外层重连循环，生产进程会因此退出。该问题直接破坏 Gateway → Node/Hermes 的持续连接及完整文本/Approval 链路，因此当前版本不符合“可继续作为完整原型正常使用”的验收标准。

此外，仓库自身冻结交付记录明确将真实 Hermes H1 纵向链路、连续 GUI、实体麦克风、Remote STT 和完整语音发行门列为未关闭。本次环境也没有 Hermes、PostgreSQL、实体麦克风、TTS 服务或 Direct LLM 凭据，相关项目未冒充通过。

## 2. 基本信息

| 项目 | 实际信息 |
| --- | --- |
| 仓库 | `Dreamy-MoLing/VoxHandoff` |
| 分支 | `main` |
| 验收 Commit | `e93fcee4a10104669bc44b990807157c3f8044e5` |
| Commit 标题 | `Merge archive snapshot into main` |
| 源码树 SHA | `58704ff11e67b19c31d258fe7eb91125639a5d38` |
| 验收日期 | 2026-08-11（Asia/Shanghai） |
| 当前状态 | 仓库已于 2026-08-06 归档，不再承诺兼容性适配或发行版本 |

### 2.1 本次实际运行环境

| 项目 | 版本/状态 |
| --- | --- |
| 操作系统 | Ubuntu 24.04.3 LTS（Noble）x86_64 |
| 虚拟化 | KVM，完全虚拟化 |
| 桌面环境 | 无；无 X11/Wayland 会话，headless 容器 |
| CPU | 9 vCPU，Intel Xeon Platinum 8171M @ 2.60 GHz |
| 内存 | 15 GiB；无 Swap |
| Node.js | v24.14.0 |
| npm | 11.9.0 |
| Python | 3.12.13；项目 STT 目标为 Python 3.11 |
| uv | 已安装；受网络审批限制，未完成本地 PyInstaller 构建 |
| Flutter | 项目固定 3.44.6 |
| Dart | 项目固定 3.12.2 |
| ffmpeg | 6.1.1 |
| Hermes | 未安装/不可用 |
| PostgreSQL | 未安装/不可用 |
| Docker/Podman | 不可用 |

项目固定 Flutter 3.44.6 Linux SDK 已下载并通过仓库记录的 SHA-256：

`a6320fd72e9a2690c08e2a6a70874a30cb120dee7c78f49d2c628bd7c9e20525`

但该 SDK 的 Dart VM 在本 KVM 环境执行任意 Dart 脚本或 Flutter tool snapshot 时均发生 `SIGSEGV`（exit 139）；`dart --version` 可运行。由于压缩包与其内部 snapshot 均通过逐字节哈希复核，此项按验收环境兼容限制记录，不作为 VoxHandoff 产品缺陷。

### 2.2 主要组件版本

| 组件 | 版本 |
| --- | --- |
| `@connectrpc/connect` | 2.1.2 |
| `@connectrpc/connect-node` | 2.1.2 |
| `@bufbuild/protobuf` | 2.12.1 |
| `@bufbuild/buf` | 1.72.0 |
| `pg` | 8.22.0 |
| TypeScript | 7.0.2 |
| Faster Whisper | 1.2.1（锁定后端；真实模型未提供） |

## 3. 证据口径

本报告区分三类证据：

- **本次实测**：在验收 Commit 工作区实际执行的命令、socket 交互和故障探针。
- **同源码树 CI**：GitHub Actions run `31073906440` 检出的 Commit 为 `5025711d8a369dc4cdebb5c445fd4624ed42ce01`；它与本次 `main@e93fcee` 的 tree SHA 均为 `58704ff...39a5d38`，文件内容完全相同。因此可作为同一源码树的构建/自动化证据，但不能替代本次人工 GUI 或实体设备操作。
- **未验收**：缺少真实服务、凭据、硬件、平台或可操作桌面时，明确标记为 `BLOCKED/NOT RUN`。

## 4. 构建、静态检查与测试

### 4.1 本次实测结果

| 项目 | 结果 | 说明 |
| --- | --- | --- |
| Git checkout | PASS | `main` 成功检出并锁定 `e93fcee...` |
| Node 依赖安装 | PASS | `npm ci` 按 lockfile 安装 36 个包；验收机需显式改用工作区 npm cache |
| 仓库/协议/TypeScript 检查 | PASS | `npm run check` 成功；510 个文件一致性检查通过，协议契约及生成文件一致 |
| 根离线测试 | PASS | `npm test`：167 passed，3 skipped，0 failed |
| Gateway HTTP/2/TLS transport | PASS | `AGENT_TALK_LOOPBACK_INTEGRATION=1 npm run test:transport`：2 passed |
| STT 离线协议测试 | PASS | 10 passed；缺失/相对模型路径正确 fail closed |
| PoC doctor | PARTIAL | Node 与 ffmpeg 可用；Hermes 不可用 |
| 本地 Flutter analyze/test | BLOCKED | Dart VM 在当前 KVM 执行脚本时 SIGSEGV |
| 本地 Linux release build | BLOCKED | 同上，且当前镜像无 GTK/Clang/CMake 开发环境 |
| 本地 STT PyInstaller bundle | BLOCKED | uv 所需外部下载未获当前环境网络许可 |

根测试的 3 个跳过项为：真实 HTTP/2 gRPC、真实 TLS Pairing、真实 PostgreSQL。前两项随后通过显式 transport gate 实际执行并通过；PostgreSQL 仍未执行。

### 4.2 同源码树 CI 结果

| 平台/门 | 结果 | 证据 |
| --- | --- | --- |
| Flutter analyze/test | PASS | `No issues found`；211 passed，2 skipped |
| Linux release | PASS | 生成 `build/linux/x64/release/bundle/agent_talk_client` |
| Linux bundled STT | PASS（构建） | PyInstaller executable 构建并安装到 `bundle/libexec/voxhandoff-stt` |
| Linux desktop integration self-test | PASS/PARTIAL | hotkey available、tray degraded、notifications available、window available |
| Linux Secure Storage | PASS | Secret Service 写入、读回、删除与删除后空读通过 |
| Windows release | PASS（仅构建） | 生成 `agent_talk_client.exe`；未启动 GUI |
| macOS release | PASS（仅构建） | CI job 成功；未启动 GUI/验证权限 |
| iOS simulator | PASS（仅构建） | CI job 成功 |
| Android | PASS（仅 debug build） | CI 构建 debug APK；不是本任务要求的 release APK |
| Node + PostgreSQL CI | PASS | CI 中真实 PostgreSQL transaction tests 与 gRPC transport tests 成功 |

## 5. 功能验收表

| 模块 | 结果 | 说明 |
| --- | --- | --- |
| 构建 | PARTIAL | Node/协议/STT 测试与同树 CI 多平台构建通过；本机 Flutter release 因验收机 Dart SIGSEGV 未执行 |
| 正常启动 | BLOCKED | 同树 CI 仅执行 desktop integration self-test；本次无可运行 GUI bundle |
| GUI | BLOCKED | 211 个 Flutter widget/golden/accessibility 自动测试通过；未完成实际窗口操作、缩放、焦点及关键状态截图 |
| Pairing | PARTIAL | 真实 loopback HTTP/2 TLS Pairing transport 通过；未完成客户端 UI、owner verification、credential 保存与重启恢复 |
| Gateway | FAIL | 短连接握手/TLS 通过；生产 Node stream 在约 30 秒被 deadline 关闭 |
| Hermes | BLOCKED | 本环境无 Hermes；仓库冻结记录也未关闭 Hermes 0.20 兼容与 H1 真链路 |
| 文本消息 | BLOCKED | fake/离线链路测试通过；真实 Flutter → Gateway → Node/Hermes → Agent E2E 未形成 |
| Streaming | FAIL | Node → Gateway 生产 transport 在 30,018 ms 报 `deadline_exceeded` |
| Approval | BLOCKED | 离线状态机、签名、CAS、Approve/Deny 测试通过；真实 Agent Approval 与断线场景未运行 |
| Reconnect | FAIL | 30 秒断流后 `HermesNodeConnector.run()` 无外层自动重连，进程退出 |
| STT | PARTIAL | 本地协议、错误边界和同树 bundled executable 构建通过；无实体麦克风/模型，未做真实识别；Remote STT 尚未形成统一生产入口 |
| TTS | BLOCKED | Piper/GPT-SoVITS adapter 自动测试存在；无真实 TTS 服务和音频设备，未播放 |
| Direct LLM | BLOCKED | 无测试凭据；仅自动化 fixtures 通过 |
| Secure Storage | PASS（同树 CI） | Linux Secret Service 实际 round-trip 成功；本次客户端重启恢复未执行 |
| 稳定性 | FAIL | 核心 Node 长连接 30 秒中断，无法达到 10 分钟完整稳定性门 |
| Android | PARTIAL | debug APK 同树 CI 构建成功；release manifest、实机联网和 Gateway 未验收 |
| macOS | PARTIAL | release 同树 CI 构建成功；App Sandbox、麦克风和实际联网未验收 |
| Windows | PARTIAL | release 同树 CI 构建成功；启动、GUI 与 Gateway 实际交互未验收 |

## 6. 关键实际复现：30 秒长连接

使用本次构建出的 Gateway/Protocol/Node 代码启动真实 loopback HTTP/2 Gateway，Node 客户端 transport 参数与生产 `services/node/src/main.ts` 一致：

```text
defaultTimeoutMs: 30_000
pingIntervalMs: 20_000
pingIdleConnection: true
pingTimeoutMs: 10_000
```

探针计划维持 70 秒，每 5 秒发送一次 Node heartbeat。实际结果：

```json
{
  "elapsedMs": 30018,
  "frames": 6,
  "errorName": "ConnectError",
  "errorCode": 4,
  "errorMessage": "[deadline_exceeded] the operation timed out"
}
```

结果表明 stream 并非异常空闲：握手后持续发送 heartbeat，仍被整个 RPC 的默认 deadline 在约 30 秒关闭。该 transport 被生产 Node 进程直接使用；`HermesNodeConnector.run()` 退出后 `main()` 没有重新连接循环，顶层 catch 设置失败退出码。

## 7. 缺陷记录

### VH-ACC-001：生产 Node → Gateway 长连接在约 30 秒强制断开

| 字段 | 内容 |
| --- | --- |
| 严重程度 | **High** |
| 环境 | Ubuntu 24.04.3 / Node 24.14.0 / ConnectRPC 2.1.2 / loopback HTTP/2 |
| Commit | `e93fcee4a10104669bc44b990807157c3f8044e5` |
| 模块 | Gateway / Node Connector / Streaming / Reconnect |
| 复现稳定性 | 稳定复现 |
| 代码位置 | `services/node/src/main.ts` 的 `createGrpcTransport({ defaultTimeoutMs: 30_000, ... })` |

复现步骤：

1. 启动实际 loopback HTTP/2 Gateway control service。
2. 使用生产同参数 `createGrpcTransport` 建立 `ConnectNode` 双向 stream。
3. 完成 Node handshake，并每 5 秒发送 heartbeat。
4. 等待超过 30 秒。

预期结果：长生命周期 stream 在心跳正常时持续保持，至少超过 60 秒。

实际结果：约 30 秒返回 ConnectRPC code 4 `deadline_exceeded`；连接关闭。

影响：Gateway → Node/Hermes 的生产通道无法稳定驻留；长请求、流式回复、Approval、interrupt 和 10 分钟稳定性均可能被直接中断。Connector 没有外层自动重连，因此不是短暂 UI 状态错误，而是进程级功能阻断。

初步定位：将面向普通 RPC 的 `defaultTimeoutMs` 应用于长生命周期双向 stream。修复时应取消该 stream 的固定全局 deadline，或只对短生命周期 unary/握手阶段设置有界 timeout，并增加超过 60 秒的真实 transport 回归测试及进程级重连测试。

日志：

```text
elapsedMs=30018
frames=6
ConnectError code=4
[deadline_exceeded] the operation timed out
```

截图/视频：无；该缺陷为协议连接级问题，以结构化探针输出为主要证据。

## 8. 未验收项目与限制

以下项目未获得实际通过结论：

- Linux release GUI 的首次启动、主工作区、设置、Pairing、Approval、录音及断线状态人工操作；
- 窗口缩放、焦点、键盘快捷操作、按钮状态与关键页面实际运行截图；
- 真实 PostgreSQL Gateway 的启动、迁移、持久化和重启恢复（仅同树 CI 通过）；
- 真实 Hermes 0.20 的 capability negotiation、10 轮文本、streaming、interrupt、Approval 和 session 恢复；
- Pairing credential 在客户端安全存储后的重启恢复；
- 实体麦克风、Faster Whisper 模型、空录音/短录音/权限失败和真实识别准确性；
- Remote STT 产品入口与上传同意流程；
- Piper/GPT-SoVITS 实际合成、播放、停止和连续回复；
- Direct LLM/OpenRouter 真实凭据请求及错误 Key；
- 客户端与完整服务同时运行 10 分钟的 CPU、内存和 UI 稳定性；
- Android release APK 与实机、macOS 实际权限/联网、Windows 实际启动/GUI。

仓库中的 golden 图片属于自动化基线，不是本次实际运行截图，因此没有把它们冒充为人工 GUI 证据。

## 9. 最终判断

当前版本具备较完整的架构、离线状态机、协议安全边界和跨平台可构建性，自动化质量明显高于一般原型；但验收目标要求的是“完整原型实际可用”，而不是“代码与测试较完整”。生产 Node 长连接约 30 秒必断已经直接否定 Gateway/Hermes 持续连接、streaming、Approval 和稳定性门；真实 Hermes、连续 GUI 和实体语音链路也仍未关闭。

因此本次结论选择：

> **FAIL：存在核心功能故障，当前版本不能作为完整原型正常使用。**

