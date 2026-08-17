# VoxHandoff 开发与交付规范（Hermes 人格化语音移动伴侣）

> 基线日期：2026-08-16（定稿基线）。本文件是重新定位后的交付基线；
> 旧版"完整 Agent 控制面"的 DELIVERY 与验收证据归档至
> `spec/archive/2026-08-16-full-agent/DELIVERY.md`。

## 0. 执行顺序（Android-first 语音移动伴侣）

0. **M0：authority cutover**（无争议，先行）——提交四份 spec；重写根
   `AGENTS.md`、根 `README.md`；修改 workspace/build/test 使旧
   Gateway/Node 退出默认开发路径；确认 `npm run check/test` 与
   `flutter:check` 在新的默认路径上全绿。
1. **S0：Hermes integration spike**（关键前置，决定 v0.1.0 主链路契约）——
   研究 Hermes 0.20.1（2026.8.13）API server 实际暴露的对话接口
   （chat/completions / responses / runs 等）、会话语义、流式/中断、认证方式
   与语音能力暴露程度；输出"v0.1.0 Hermes 主链路契约"结论，更新 PRODUCT/
   ARCHITECTURE 中"以 S0 spike 结论为准"的占位。
2. **M1：Hermes 对话主链路**——按 S0 契约实现/接通 Hermes 对话 adapter；
   配置 → 连接测试 → 文本聊天 → 消息终态 → 重启恢复 真机闭环。
3. **M2：语音输入**——复用已打通资产（录音 → 远程 STT → 中文草稿 →
   确认），纳入 Call/Command 双模式验收。
4. **M3：TTS/降级与 Call Mode**——明确 TTS provider，Call Mode 稳定句播报
   与打断（barge-in），文字结果独立于播放失败。
5. **M4：实体 Android 验收**——安装、权限、重启、断网、重连、连续交互、
   日志脱敏、发布构建与 release signing。

每个阶段都必须有可复现检查和独立结果；失败、阻塞和未验证不能写成完成。

## 1. 当前资产（复用）

- 移动端 SignalCore 视觉基线（待机/文字/录音/连接四态 + 设置页）已冻结，
  桌面 golden 保持零变化；
- 自实现 Kotlin AudioRecord 原生桥（16 kHz PCM、MethodChannel/EventChannel）；
- 远程 STT HTTPS adapter（`services/stt`，/v1 契约，faster-whisper base）；
- 远程 STT CA 独立存储（`SecureRemoteSttTrustedRootCertificateStore`），
  未配对设备可导入；
- 消息终态、确认快照、客户端状态机；
- 真实录音→STT→中文草稿→确认 已在 vivo V2359A 打通（`POST /v1/transcribe
  200`）。
- 旧 Gateway/Node/PostgreSQL 实现已归档冻结，作为未来升级路径。

## 2. 里程碑

| 里程碑 | 内容 | 门 |
| --- | --- | --- |
| M0 authority cutover | spec 提交、AGENTS.md/README 重写、旧模块退出默认路径 | `flutter:check`、`npm run check/test` 新路径全绿 |
| S0 integration spike | Hermes 0.20.1 API 能力审计，确定 v0.1.0 主链路契约 | 输出契约结论并回写 spec |
| M1 Hermes 对话主链路 | 按 S0 契约接通 Hermes 对话；文本真机闭环 | 配置→测试→聊天→终态→重启恢复 |
| M2 语音输入 | 录音→STT→草稿→确认（复用已打通资产） | 真机 readiness + 真实录音 200 |
| M3 TTS/降级与 Call Mode | 明确 TTS provider、稳定句播报、barge-in | 播放成功、打断生效、TTS 失败不阻塞文字 |
| M4 实体验收 | 权限/重启/断网/重连/连续交互/脱敏/签名 | 发布构建 + 真机矩阵 |
| M5-SIG | 视觉状态机对齐 Hermes 主链路（SignalCore 四态/工作态语义对齐） | 桌面 golden 零变化 + 视觉状态机接线 |
| M6 onboarding | 配对式首次配置（QR + certificate pin + Companion Bridge），见 `design/onboarding-qr-pairing.md` | 待实施项 1-8 完成 + 安全测试 |
| H1（冻结） | Hermes 深度 Agent 集成（旧控制面） | 等 Hermes 上游补齐 run 幂等 + approval ID |

## 1.5 当前进度（2026-08-17 更新，依据 git log / 合并状态）

- **已完成并合并 main**：M0、S0（契约定案已回写 PRODUCT 5.2 / ARCHITECTURE 2）、M1（Hermes 对话主链路界面与流式传输）、M2（语音双模式 Call/Command 接入，`agent/m2-complete` 已合并）、M3（稳定句播报 + barge-in，`agent/m3-tts-stream`/`agent/m3-voice-loop` 已合并）、M5-SIG（视觉状态机对齐 Hermes 主链路）。
- **部分就绪**：M4 相关资产（release 签名配置 154f1e9、密钥回退 debug）已提交；实体验收矩阵与 50 次端到端证据待 M6 落地后统一收口。
- **实施中**：M6 onboarding（design 定稿 2026-08-17 00:02；任务已按 8 项待实施拆包，2026-08-17 启动）。
- **M6 第一/二波完成并合并 main（2026-08-17）**：T1 Companion Bridge 主机侧组件（services/bridge，pairing/凭据/pin/manifest/proxy，23+26 tests）；T2 手机端安全配对（QR 扫描 + Android Keystore P-256 + SPKI pin + 状态机 + 凭据 vault，323+ tests）；T3 Capability Manifest 模型/UI + 裸 TOFU 手动连接（347+ tests）；T4 文档同步（DECISIONS 重建 D-039）；T5 配对契约对齐（Bridge 补手机 status/cancel/自撤销端点，Ed25519 + ECDSA P-256 双算法签名，26/26 bridge tests）。整体 `npm run check` 与 `flutter:check` 全绿（368+ tests）。
- **M6 剩余**：① 接线真实 `BridgeCapabilityManifestRepository`（当前为占位）；② 真机联调验收（扫码→Keystore→pin→配对→凭据→撤销，需 vivo V2359A）；③ 待实施项 7（PRODUCT.md 4.1 重写为配对流程，联调通过后）；④ 待实施项 8 安全测试收口。
- 说明：上表 M0-M4/H1 为 2026-08-16 定稿基线；M5-SIG、M6 为本轮按实际开发状态补录的里程碑定义。

## 3. 开发规则（沿用 + 调整）

- TypeScript 严格；协议边界避免 any；
- 每次功能实现/修复完成后立即创建本地提交（conventional commits、中文
  说明），按功能域拆分，不积压跨域改动；收工前 `git status` 干净；
- 阶段性成功可 push 备份，但不要触发 CI（CI 仅 workflow_dispatch）；
- **分层策略调整**：单人项目一个 milestone 一个 branch，内部按逻辑提交；
  只有数据库 migration、协议契约、安全边界、大型跨层改造才强制 stacked PR
  （数据→API→接线→UI）。日常小改动不再强制拆多分支。
- **任务粒度**：Hermes 读取 spec 决定当前 milestone；Codex 每次只拿一个
  明确任务包（目标/非目标/允许改动区域/验收命令/必须提交的证据）；一个
  milestone 结束后重新开 Codex 上下文，由 Hermes 独立检查 diff/test；
  产品规格修改单独做 decision，不由实现中的 Codex 顺手改 spec；
- spec/ 是唯一权威基线；docs/ 不引用。

## 4. 测试矩阵

### 4.1 每次变更

- formatting/lint/type check；core/adapter unit tests；Drift 生成文件新鲜度；
  secret fixture 与日志脱敏测试。

### 4.2 合并前

- 相关 integration/失败注入；断线/乱序/重复/超时/取消/终态；
- UI golden/accessibility；依赖/许可证变更说明。

### 4.3 发布门（v0.1.0）

- 所有非协商安全测试通过；
- 无已知 Critical/High 可利用漏洞；
- 50 次端到端成功率 ≥ 95%；Hermes 对话连续 10 轮不串线；
- 安装、升级、卸载不删除未明确选择删除的数据；
- release signing 完成；debug signing 不作为发布证据；
- hard gate 延迟达标（见 PRODUCT.md 7.1），observed 指标记录不设硬门。

## 5. 明确不在 v0.1.0

- Gateway/Node/PostgreSQL 控制面（冻结）；
- Hermes 审批面板深度集成；
- 后台监听/唤醒词/全双工（唤醒词属 Hermes 内建，不在 VoxHandoff 范围）；
- 流式 STT 临时字幕（Call Mode 升级项）；
- Direct LLM 作为主链路（延后可选）；
- iOS/macOS/Windows 客户端（后续里程碑）；
- 附件上传（未定义规格前不承诺）。

## 6. 历史

v1（完整 Agent 控制面）规格、架构、交付与决策记录已归档至
`spec/archive/2026-08-16-full-agent/`，仅作为未来升级路径参考。
