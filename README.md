# VoxHandoff

> **项目已归档；有限验收维护：2026-08-11**

VoxHandoff 曾是面向 Hermes 用户的本地优先、GUI 优先个人语音助手。项目
组合了 Flutter 客户端、Gateway/PostgreSQL 耐久控制面、Hermes Node
Connector、可配置 STT/TTS 端口，以及独立的 OpenAI-compatible 纯聊天路径。

项目后续开发现已停止。Hermes Agent [v0.20.0](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.8.3) 于 2026-08-03 发布，已经把本项目原本要补齐的核心体验纳入官方产品：流式会话语音、barge-in 打断、设备端唤醒词、可配置 STT、多 profile 语音路由和支持语音的 Gateway surface，同时提供 A2A v1.0 集成。继续维护同一层 GUI 语音能力会与上游重复。

本仓库作为公开工程记录保留。它不再是当前 Hermes 的替代实现，也不再
承诺新的功能、兼容性适配或发行版本。2026-08-11 的维护范围仅修复已实测
的 Node→Gateway 长连接验收故障，不重新开启产品路线或把未实测的服务、GUI
和实体设备门写成通过。

## 已完成的工作

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
产品与架构文档保留在 [`spec/`](spec/README.md)，用于理解历史设计和实现。

## 代码保留的关键边界

- Hermes 是本项目唯一具有 Agent/work 语义的后端。
- Direct LLM 只提供纯聊天，不模拟 Agent 工具、审批、执行主机、lease 或 Hermes 状态。
- 确认发送绑定不可变文本、上下文、backend 和 target 快照。
- STT、TTS、摘要生成或播放失败时，完整文字回复仍可用。
- 远端接受结果不确定时进入 `uncertain`，提交不会静默重试。
- 秘密和原始录音默认留在本地；过期 identity、sequence 或 capability 会在协议边界 fail closed。

## 目录索引

- [`packages/core`](packages/core)：领域类型、生命周期、脱敏和确定性语音摘要规则。
- [`packages/adapters`](packages/adapters)：Hermes transport 和历史回归 adapter。
- [`apps/poc-cli`](apps/poc-cli)：协议与故障注入验收 harness。
- [`apps/client`](apps/client)：共享 Flutter 客户端。
- [`services/gateway`](services/gateway)：认证控制面和 PostgreSQL ledger。
- [`services/node`](services/node)：出站 Hermes Connector。
- [`services/stt`](services/stt)：可选的版本化本地 STT sidecar。
- [`spec/`](spec)：归档的产品、架构和交付基线。

## 分支收敛

`agent/m2-complete`、`agent/m3-voice-loop` 和 `agent/m4-fairy-desktop`
的提交均已合入 `main`。维护分支 `agent/acceptance-repair` 用于保存本次
验收修复和复验；合入后可删除已合并的历史 topic branch，不应重复合并其历史。

## 本地验证

仓库已停止开发，验证可能需要固定工具链和可选本地服务。原有质量入口为：

```bash
npm install
npm run check
npm test
AGENT_TALK_LOOPBACK_INTEGRATION=1 npm run test:transport
npm run poc -- doctor
```

固定 Flutter 门：

```bash
AGENT_TALK_FLUTTER_ROOT=/home/roco/develop/flutter-3.44.6 npm run flutter:check
```

离线检查不能证明尚未完成的实体麦克风 GUI 流程、第三方服务行为、签名
安装包或 Hermes 0.20.0 兼容性。v0.20.0 发布说明证明的是上游能力，不是
本仓库历史 Connector 协议的兼容测试。

## License 状态

当前快照没有 `LICENSE` 文件。仓库公开可见不等于授予代码复用权；如需
允许复用，应另行添加明确的许可证。
