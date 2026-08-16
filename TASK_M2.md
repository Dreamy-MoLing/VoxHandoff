# VoxHandoff 任务书 M2：语音双模式（Call/Command）接入

> 依据：spec/PRODUCT.md 4.2-4.4（Call/Command 双模式定义）、spec/ARCHITECTURE.md
> 3.3（交互模式组件）。目标：把 VoiceSession 接入 Call/Command 双模式，保留
> 已打通的录音→STT→草稿→确认链路。
> 注意：本任务与 M1（Hermes 对话主链路）并行，发送动作只通过现有
> ChatSource 抽象调用，**不实现 Hermes adapter**（M1 负责，合并后接线）。

## 1. 现状（Hermes 已核实）

- 语音链路已打通（vivo V2359A 真机验证）：`VoiceSessionController`
  （`apps/client/lib/application/voice_session_controller.dart`）：
  startRecording → stopRecording → transcribing → **awaitingConfirmation**
  （final transcript 可编辑/确认）→ discardTranscript/cancelRecording。
- 当前行为 = 单一"显式确认"流程（即 Command Mode 形态）；
  **还没有 Call Mode**（录音结束即发送 + 轻量回显 + 1 键取消）。
- 发送通道：`ChatSource` controller 已有（`lib/application/chat_source_controller.dart`），
  本轮不改它；Call Mode 的"发送"先调用现有发送接口（可能是
  `chatSourceController` 或等价），若 M1 未合并导致接口暂缺，用清晰 TODO
  桩 + 说明，不自己实现 Hermes transport。
- UI：`lib/presentation/voice_settings_sheet*.dart`（设置）、
  `lib/presentation/conversation_view.dart` / `direct_chat_view.dart`
  （对话区）。
- 本地存储：`lib/application/local_transcript_store.dart` 相关已有。

## 2. 目标

1. **模式模型**：引入 `InteractionMode { call, command }`（domain 层，如
   `lib/domain/interaction_mode.dart`），含持久化（设置里可选默认模式，
   存本地；可用 Drift 或现有 settings store，优先复用现有机制）。
2. **VoiceSession 双模式流程**：
   - Command Mode：维持现状（awaitingConfirmation 显式确认）；
   - Call Mode：停止录音 → STT → **轻量回显**（新 UI 态，如
     `awaitingCallConfirm`：一句话回显 + 1 键取消/1 键确认发送）→ 发送；
   - 用户可在录音前/设置中切换模式；**工作型指令（审批/发布/删除/付款/
     授权/sudo 等敏感词）即使 Call Mode 也强制回退 Command 级确认**（简单
     关键词启发式即可，后续可增强）。
3. **UI 接线**：录音按钮/长按行为按模式呈现（Call 模式松手即发 + 回显条；
   Command 模式松手进确认页）；设置页加"交互模式"选择。
4. **保留**：已打通的 STT 链路、可编辑草稿、取消/丢弃、失败降级文字全部
   不回退。

## 3. 执行顺序

### Phase 1：模式模型
- `InteractionMode` enum + 默认模式持久化（复用现有 settings/local store；
  没有现成机制就最小新增，不引入新依赖）。

### Phase 2：VoiceSession 双模式
- `VoiceSessionState` 增加 `interactionMode`、`awaitingCallConfirm` 阶段；
- `stopRecording` 分支：command → 现状；call → 进入回显阶段；
- 回显确认/取消/超时（如 15s 无操作自动丢弃）语义；
- 敏感词回退（简单关键字列表）。

### Phase 3：UI
- 录音交互按模式呈现（长按松手行为差异）；
- Call 回显条（显示一句话 + 发送/取消）；
- 设置页"交互模式"入口；
- 状态文案/无障碍标签更新。

### Phase 4：测试
- 定向测试：模式持久化、call 回显流程、command 保留原流程、敏感词回退、
  取消/丢弃；
- 真机（若 adb 在线 vivo）：录音 → Call 模式回显 → 发送；Command 模式
  确认；确认旧链路不回退；
- `flutter:check` 全绿（桌面 golden 零变化约束——若本轮必须改手机 golden
  需在报告中说明）。

### Phase 5：提交
- 中文 conventional commits，按功能域拆分；**不 push、不触发 CI**。

## 4. 硬边界

- **不实现 Hermes transport/adapter**（M1 负责）；发送走现有 ChatSource
  抽象，接口暂缺用 TODO 桩 + 说明；
- 不改 spec/ 任何文件；不新增无关依赖（优先复用现有 settings/store）；
- 不自动批准任何东西；不伪造证据；无法实测写"未验证"；
- 移动端不启动本地 sidecar；
- 桌面 golden 尽量零变化；确需变化时明确报告。

## 5. 报告格式（输出 /tmp/voxhandoff-m2-report.md）

1. 新增/改动文件清单 + 职责
2. InteractionMode 模型与持久化摘要
3. VoiceSession 双模式流程实现要点（含敏感词回退）
4. UI 改动摘要
5. 测试结果（定向 + 真机/本机；三条门命令输出摘要）
6. 未提交改动清单（提交由协调者统一安排）
