# VoxHandoff

VoxHandoff 是以 Hermes 为唯一首发 Agent 的安全、本地优先跨平台语音中继。它覆盖 Windows、Linux、macOS、iOS 和 Android：将语音转成可编辑文字，只把用户确认的文字交接给明确选择的 Hermes 会话，保留完整回复，并使用独立短文本进行语音播报。

当前工作集中在真实 Flutter → Gateway → Hermes Connector 纵向链路与 Hermes MVP 界面；Codex/OpenClaw 扩展和发行工作暂停。正式开发只以 [`spec/`](spec/README.md) 为准：

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
