# VoxHandoff Spec 说明

## 这是什么

VoxHandoff 是 Hermes 的**第三方 voice-first mobile companion**（
2026-08-16 定位）：把 Hermes 变成一个人格化、低摩擦、接近电话交流体验的
私人助手。手机负责录音、转写确认、聊天、播放、记忆呈现、人格与 SignalCore
视觉；Agent 能力属于 Hermes。与官方 mobile shell（Hermes Desktop 移动镜像）
的差异在人格化与电话式体验。

## 文档

| 文件 | 内容 |
| --- | --- |
| `PRODUCT.md` | 产品需求、功能、非功能与安全约束（定稿基线） |
| `ARCHITECTURE.md` | 技术架构、组件边界、数据流与安全边界（定稿基线） |
| `DELIVERY.md` | 执行顺序（M0/S0/M1-M4）、里程碑、测试矩阵与发布门 |
| `design/onboarding-qr-pairing.md` | 配对式首次配置设计基线（QR + certificate pin + Companion Bridge，**已定稿 2026-08-17**） |
| `archive/2026-08-16-full-agent/` | 旧版"完整 Agent 控制面"规格/架构/交付/决策归档 |

## 当前状态

- Android-first，v0.1.0 目标平台；
- 定位：Hermes 人格化语音移动伴侣（Call Mode + Command Mode）；
- Hermes 对话接口为 v0.1.0 主后端，契约以 S0 integration spike 结论为准；
- 语音输入链路（录音 → 远程 STT → 中文草稿 → 确认）已在 vivo V2359A 打通；
- STT/TTS 适配层自研保留（Hermes 语音是内建体验，无第三方 HTTP API）；
- Hermes 深度 Agent 集成（工具/审批）冻结，等 Hermes 上游补齐能力后作为
  升级路径。
