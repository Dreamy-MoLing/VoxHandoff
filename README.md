# Agent Talk

Agent Talk 是面向 Codex、Hermes、OpenClaw 和未来 Agent 的本地优先跨平台语音客户端。它覆盖 Windows、Linux、macOS、iOS 和 Android：将语音转成可编辑文字，通过官方 Agent 协议提交已确认请求，保留完整回复，并使用独立短文本进行语音播报。

项目当前处于协议核心阶段。正式开发只以 [`spec/`](spec/README.md) 为准：

- [产品规格](spec/PRODUCT.md)
- [技术架构](spec/ARCHITECTURE.md)
- [开发与交付规范](spec/DELIVERY.md)

快速验证：

```bash
npm install
npm run check
npm test
npm run protocol:codex
npm run poc -- doctor
```

原 `docs/` 已完成吸收，仅作为本地历史输入保留并被 Git 忽略，不再参与需求、架构或验收决策。
