# VoxHandoff 开发与交付规范（v2：移动端人格化交互层）

> 基线日期：2026-08-16。本文件是 v2 重新定位后的交付基线；旧版
> "完整 Agent 控制面"的 DELIVERY 与验收证据归档至
> `spec/archive/2026-08-16-full-agent/DELIVERY.md`。

## 0. v2 执行顺序（Android-first）

1. 基线收口：确认现有资产（SignalCore 视觉、四态交互、录音桥、STT HTTPS
   adapter、Direct LLM、记忆/确认状态机）在当前 main 可构建、可测试；
   冻结模块（gateway/node）从产品主链路中移除。
2. 对话主链路：Direct LLM Provider Profile 真机闭环（配置 → 测试 → 聊天 →
   消息终态 → 重启恢复）。
3. 语音输入：前台录音 → 远程 STT → 可编辑草稿 → 确认（已打通，纳入验收）。
4. TTS/降级：接入一个明确 TTS provider，验证文字结果独立于播放失败。
5. 实体 Android 验收：安装、权限、重启、断网、重连、连续交互、日志脱敏、
   发布构建与 release signing。

每个阶段都必须有可复现检查和独立结果；失败、阻塞和未验证不能写成完成。

## 1. 当前资产（v2 复用）

- 移动端 SignalCore 视觉基线（待机/文字/录音/连接四态 + 设置页）已冻结，
  桌面 golden 保持零变化；
- 自实现 Kotlin AudioRecord 原生桥（16 kHz PCM、MethodChannel/EventChannel）；
- 远程 STT HTTPS adapter（`services/stt`，/v1 契约，faster-whisper base）；
- 远程 STT CA 独立存储（`SecureRemoteSttTrustedRootCertificateStore`），
  未配对设备可导入；
- Direct LLM（OpenAI-compatible chat）与消息终态、记忆/摘要、确认快照；
- 真实录音→STT→中文草稿→确认 已在 vivo V2359A 打通（`POST /v1/transcribe
  200`）。

## 2. 里程碑（v2）

| 里程碑 | 内容 | 门 |
| --- | --- | --- |
| M1 基线收口 | 冻结模块移除、构建/测试门全绿、文档基线更新 | `flutter:check`、`npm run check/test` |
| M2 对话主链路 | Direct LLM 真机闭环 | 配置→测试→聊天→终态→重启恢复 |
| M3 语音输入 | 录音→STT→草稿→确认（复用已打通资产） | 真机 readiness + 真实录音 200 |
| M4 TTS/降级 | 明确 TTS provider + 播放/停止/降级 | 播放成功、TTS 失败不阻塞文字 |
| M5 实体验收 | 权限/重启/断网/重连/连续交互/脱敏/签名 | 发布构建 + 真机矩阵 |
| H1（冻结） | Hermes 深度 Agent 集成（旧控制面） | 等 Hermes 上游补齐 run 幂等 + approval ID |

## 3. 开发规则（沿用）

- TypeScript 严格；协议边界避免 any；
- 每次功能实现/修复完成后立即创建本地提交（conventional commits、中文
  说明），按功能域拆分，不积压跨域改动；收工前 `git status` 干净；
- 阶段性成功可 push 备份，但不要触发 CI（CI 仅 workflow_dispatch）；
- 跨域功能按 stacked PR 分层交付（数据→API→接线→UI，每层一个分支/PR）；
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
- 50 次端到端成功率 ≥ 95%；Direct LLM 连续 10 轮不串线；
- 安装、升级、卸载不删除未明确选择删除的数据；
- release signing 完成；debug signing 不作为发布证据。

## 5. 明确不在 v0.1.0

- Gateway/Node/PostgreSQL 控制面（冻结）；
- Hermes 审批面板深度集成；
- 后台监听/唤醒词/全双工；
- iOS/macOS/Windows 客户端（后续里程碑）；
- 附件上传（未定义规格前不承诺）。

## 6. 历史

v1（完整 Agent 控制面）规格、架构、交付与决策记录已归档至
`spec/archive/2026-08-16-full-agent/`，仅作为未来升级路径参考。
