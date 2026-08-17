# VoxHandoff

> **当前定位：第三方 Hermes voice-first mobile companion；Android-first v0.1.0：2026-08-16**

VoxHandoff 是 Hermes 的第三方 voice-first mobile companion：让 Hermes
拥有更人格化、更接近电话交流的 Android 手机体验。手机负责录音、转写确认、
聊天、播放、记忆呈现、人格和 SignalCore 视觉；Agent 能力属于 Hermes。

v0.1.0 的主后端是 Hermes 对话接口，具体契约以 S0 integration spike 结论为
准；STT/TTS 适配层由本项目自研保留。Direct LLM 只作为延后的可选纯聊天路径，
不模拟 Hermes 的 Agent 工具、审批、执行主机或工作状态。

当前只实现 Android 前台能力；iOS、桌面新功能、后台监听、唤醒词、全双工语音、
本地手机 sidecar 和新 Agent 后端不属于 v0.1.0。Hermes 深度 Agent 集成及旧
Gateway/Node/PostgreSQL 控制面已冻结，保留在代码库和
[`spec/archive/2026-08-16-full-agent/`](spec/archive/2026-08-16-full-agent/)
作为升级路径参考。

当前状态、验收证据和未关闭的发布门以 [`spec/README.md`](spec/README.md)、
[`spec/PRODUCT.md`](spec/PRODUCT.md)、[`spec/ARCHITECTURE.md`](spec/ARCHITECTURE.md)
和 [`spec/DELIVERY.md`](spec/DELIVERY.md) 为准。未实测的 Hermes、STT/TTS、GUI、
实体设备和发布门不能写成通过。

## 历史工程阶段（归档记录）

下表记录旧版完整 Agent 控制面阶段，不代表 v0.1.0 的默认构建路径或当前发布通过。

| 阶段 | 归档时状态 | 主要成果 |
| --- | --- | --- |
| M-1 / M0 | 完成 | 产品基线、威胁模型、无依赖 Agent Core、协议 taxonomy、失败/状态测试，以及隔离 Codex/Hermes PoC。 |
| M1 | 完成 | 版本化 Protobuf、认证 Gateway 流、PostgreSQL acceptance/event ledger、outbox、replay、lease、配对和耐久 approval/clarification 状态。 |
| M2 | 完成 | Flutter 文字工作区、Drift 事件账本、cursor 恢复、多设备收敛、安全存储和五平台 CI/构建门。 |
| M3 | 工程完成；推荐语音 profile 未达标 | 录音、本地/远程 STT 边界、可编辑转写确认、TTS/播放取消、失败隔离和 text-first 降级。 |
| M4 / M6 | UI 与桌面性能工作完成；发行矩阵未关闭 | SignalCore 状态视觉、GLSL/静态回退、Wayland 桌面能力降级、长历史渲染和 60/120 Hz 证据。 |
| M5 | 实现基座完成；GUI/发行门未关闭 | Direct LLM 纯聊天、Provider/凭据/历史隔离、不可变 `ConfirmedDraft`、请求所有权与有界 I/O、conversation context、语音设置、Piper/GPT-SoVITS adapter 和 STT sidecar 打包工作。 |
| H1 | 未关闭 | 真实 Flutter → Gateway/PostgreSQL → Connector → Hermes 链路仍对历史 Hermes 0.19 合约保持 fail closed；幂等 run submission 与精确 approval identity/resolution 没有完成兼容验证。 |

详细证据、验收边界和已知缺口保留在[交付记录](spec/DELIVERY.md)。
产品与架构文档的当前入口是 [`spec/README.md`](spec/README.md)；旧版完整 Agent
控制面仅用于理解归档设计和升级路径。

## 代码保留的关键边界

- Hermes 是本项目唯一具有 Agent/work 语义的后端，也是 v0.1.0 对话主链路的后端。
- Direct LLM 只提供纯聊天，不模拟 Agent 工具、审批、执行主机、lease 或 Hermes 状态。
- 确认发送绑定不可变文本、上下文、backend 和 target 快照；工作型授权仍在 Hermes 端处理。
- STT、TTS、摘要生成或播放失败时，完整文字回复仍可用。
- 远端接受结果不确定时进入 `uncertain`，提交不会静默重试。
- 秘密和原始录音默认留在本地；过期 identity、sequence 或 capability 会在协议边界 fail closed。

## 目录索引

- [`packages/core`](packages/core)：领域类型、生命周期、脱敏和确定性语音摘要规则。
- [`packages/protocol`](packages/protocol)：保留的版本化协议资产，服务冻结升级路径。
- [`packages/adapters`](packages/adapters)：Hermes 对话 adapter 主链路、延后可选 Direct LLM 和历史回归 adapter。
- [`apps/poc-cli`](apps/poc-cli)：协议与故障注入验收 harness。
- [`apps/client`](apps/client)：Android-first Flutter 客户端。
- [`services/stt`](services/stt)：版本化 STT 适配/服务边界；手机不启动本地 sidecar。
- [`services/gateway`](services/gateway)：冻结归档的旧控制面和 PostgreSQL ledger，不进入 v0.1.0 默认路径。
- [`services/node`](services/node)：冻结归档的旧 Hermes Connector，不进入 v0.1.0 默认路径。
- [`spec/`](spec)：当前产品、架构和交付基线；权威入口为 [`spec/README.md`](spec/README.md)。

## 分支收敛

历史 topic 分支（`agent/m2-complete`、`agent/m3-voice-loop`、
`agent/m4-fairy-desktop` 等）均已合入 `main` 并已清理删除。当前仅保留
`main` 与进行中的 milestone 分支（M6 onboarding：`agent/m6-*`），
合入后可删除已合并的历史 topic branch，不应重复合并其历史。

## 本地验证

验证可能需要固定工具链和可选本地服务。默认质量入口为：

```bash
npm install
npm run check
npm test
npm run poc -- doctor
```

冻结旧模块的 PostgreSQL/transport 门仍可显式 opt-in，默认入口不会调用它们：

```bash
npm run test:postgres
AGENT_TALK_LOOPBACK_INTEGRATION=1 npm run test:transport
```

固定 Flutter 门：

```bash
AGENT_TALK_FLUTTER_ROOT=/home/roco/develop/flutter-3.44.6 npm run flutter:check
```

离线检查不能证明尚未完成的实体麦克风 GUI 流程、第三方服务行为、签名
安装包或 Hermes 对话接口兼容性。上游发布说明证明的是上游能力，不是本仓库
冻结 Connector 协议的兼容测试。

## License 状态

当前快照没有 `LICENSE` 文件。仓库公开可见不等于授予代码复用权；如需
允许复用，应另行添加明确的许可证。
