# VoxHandoff

VoxHandoff 是面向 Codex、Hermes、OpenClaw 和未来 Agent 的安全、本地优先跨平台语音中继。它覆盖 Windows、Linux、macOS、iOS 和 Android：将语音转成可编辑文字，只把用户确认的文字交接给明确选择的 Agent，保留完整回复，并使用独立短文本进行语音播报。

项目已完成 M3 的文字 + 可确认语音闭环；当前 Fedora CPU/base 语音 profile 经 30/30/50 实测被明确降级，推荐自动语音仍须在更强 STT/加速 TTS profile 上过门。正式开发只以 [`spec/`](spec/README.md) 为准：

- [产品规格](spec/PRODUCT.md)
- [技术架构](spec/ARCHITECTURE.md)
- [开发与交付规范](spec/DELIVERY.md)

快速验证：

```bash
npm install
npm run check
npm test
npm run test:stt
npm run protocol:codex
npm run poc -- doctor
```

原 `docs/` 已完成吸收，仅作为本地历史输入保留并被 Git 忽略，不再参与需求、架构或验收决策。
