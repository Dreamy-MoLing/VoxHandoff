# VoxHandoff Spec 说明

## 这是什么

VoxHandoff 是面向 Hermes 用户的**移动端人格化语音交互层**（v2，2026-08-16
重新定位）：手机负责录音、转写确认、聊天、播放、记忆、人格与 SignalCore
视觉；Agent 后端能力属于 Hermes，本产品不重新建立独立 Agent 控制面。

## 文档

| 文件 | 内容 |
| --- | --- |
| `PRODUCT.md` | 产品需求、功能、非功能与安全约束（v2 基线） |
| `ARCHITECTURE.md` | 技术架构、组件边界、数据流与安全边界（v2 基线） |
| `DELIVERY.md` | v2 执行顺序、里程碑、测试矩阵与发布门 |
| `archive/2026-08-16-full-agent/` | 旧版"完整 Agent 控制面"规格/架构/交付/决策归档 |

## 当前状态

- Android-first，v0.1.0 目标平台；
- 语音输入链路（录音 → 远程 STT → 中文草稿 → 确认）已在 vivo V2359A 打通；
- 主对话链路为 Direct LLM（OpenAI-compatible chat）；
- Hermes 深度 Agent 集成（工具/审批）冻结，等 Hermes 上游补齐能力后作为
  升级路径。
