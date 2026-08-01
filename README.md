# VoxHandoff

VoxHandoff 是面向 Hermes 用户的本地优先、GUI 优先个人语音助手。用户面对同一个可配置的助手人格、声音、记忆、SignalCore 和交互偏好：日常聊天与陪伴可以使用用户自接的 OpenAI-compatible LLM API；工具调用、任务执行、审批、控制租约、执行主机和真实 Agent 状态由 Hermes 提供。

Flutter 客户端共享 Windows、Linux、macOS、iOS 与 Android 产品语义，但各平台的真实发行门仍分别验收。Hermes 是当前主要支持且唯一具有 Agent 语义的后端；Direct LLM 只是由本机直接访问的纯聊天来源，不能伪装工具、审批、lease 或执行状态。当前 M5 已有 Direct LLM、STT/TTS adapter 和真实服务证据，但 Provider/凭据/历史隔离、确认目标绑定、请求终态与长期上下文仍需修复，实体麦克风 GUI 验收仍未完成。H1 的真实 Flutter → Gateway/PostgreSQL → Connector → Hermes 纵向链路继续受 Hermes 0.19 未广告幂等 run submission、协商结果 fail closed 为 `idempotency=false` 阻断。

正式开发只以 [`spec/`](spec/README.md) 为准：

- [产品规格](spec/PRODUCT.md)
- [技术架构](spec/ARCHITECTURE.md)
- [开发与交付规范](spec/DELIVERY.md)

快速验证：

```bash
npm install
npm run check
npm test
npm run test:stt
npm run poc -- doctor
```

原 `docs/` 已完成吸收，仅作为本地历史输入保留并被 Git 忽略，不再参与需求、架构或验收决策。
