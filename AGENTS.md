# VoxHandoff repository guide

## Product contract

VoxHandoff is a third-party voice-first mobile companion for Hermes users. The
Android-first v0.1.0 client owns recording, transcript confirmation, chat,
playback, memory presentation, persona, and SignalCore visuals; Hermes owns
Agent/work capabilities. The Hermes conversation interface is the v0.1.0 main
backend, while the STT/TTS adapter layer remains VoxHandoff-owned. Direct LLM
chat is delayed and optional, and must not be treated as Hermes Agent state.
Text is editable before send, confirmation is bound to an explicit target
snapshot, and complete replies remain independent from STT, TTS, and playback
failures.

`spec/` is the only active product and engineering baseline:

- `spec/PRODUCT.md` defines product behavior and acceptance targets;
- `spec/ARCHITECTURE.md` defines technical and security boundaries;
- `spec/DELIVERY.md` defines milestones, tests, release gates, and the current evidence state;
- `spec/archive/2026-08-16-full-agent/` retains the former full Agent control-plane baseline for upgrade reference only.

The root `docs/` directory contains absorbed pre-development research. It is ignored by Git and must not be used as a current requirement source or referenced by new code, tests, issues, or documents.

## Non-negotiable behavior

- Never auto-approve an Agent permission, clarification, secret, sudo, deletion, publishing, payment, or authorization request; work approval remains Hermes-owned.
- Never silently retry a submission whose remote acceptance is uncertain.
- Keep full text independent from STT, summary generation, TTS, and audio playback failures.
- Reject stale events by connection/session/request identity and monotonic sequence.
- Keep raw recordings local by default and redact secrets from logs and diagnostic exports.
- Do not expose Hermes or an unauthenticated endpoint directly to a public network.

## Architecture boundaries

- `packages/protocol`: versioned protocol artifacts retained for the frozen upgrade path; they are not the v0.1.0 product control plane.
- `packages/core`: dependency-free domain types, lifecycle/state machine, redaction, confirmation snapshots, and deterministic speech-summary rules.
- `packages/adapters`: the Hermes conversation adapter for the v0.1.0 main path, plus delayed optional Direct LLM and isolated historical regression adapters. Translate protocol details into `@agent-talk/core`; never leak them into UI state.
- `apps/poc-cli`: executable protocol and failure-injection PoCs. This is the acceptance harness, not a disposable demo.
- `apps/client`: Android-first Flutter UI for recording, transcript confirmation, conversation, playback, memory presentation, and SignalCore. Mobile never starts a local process or sidecar.
- `services/stt`: versioned STT adapter/service boundary. The client uses an explicitly consented remote provider or host-side service; mobile never starts the local sidecar.
- `services/gateway` and `services/node`: frozen (archived) full Agent control-plane modules; they are retained as an upgrade path and are not part of the v0.1.0 implementation baseline or default build/check/test path.

## Development rules

- TypeScript is strict; avoid `any` at protocol boundaries. Parse untrusted payloads from `unknown` with small guards.
- Prefer Node built-ins in protocol code. Add dependencies only when they materially improve correctness or portability.
- Prefer official protocols and mature community components. Record license, platform coverage, maintenance evidence, and an exit path for each infrastructure dependency.
- Keep adapter tests offline with fixtures/fakes. Live tests must be explicit and must not mutate user data without a clear prompt.
- Use opaque IDs. Do not derive security decisions from display labels.
- 每次功能实现/修复完成后立即创建本地提交（conventional commits），按功能域拆分、不积压跨域改动；收工前 `git status` 必须干净（仅剩被 ignore 项）。
- 提交说明统一使用**中文**（subject + body），格式沿用 conventional commits（`fix: `、`feat: `、`docs: ` 等前缀）。阶段性成功可 push 到云端备份，但**不要触发 CI**：产品完备前 CI 仅保留 `workflow_dispatch` 手动触发。
- **分层交付（stacked PR）**：跨域功能（如数据+API+UI 同时改动）必须按依赖链拆层提交：数据层 → API 层 → 接线层 → UI 层，每层一个分支、一个提交组、一个 PR，上层基于下层分支；禁止把整个功能塞进一个巨型 PR。详见 `spec/DELIVERY.md` 第 12 节。

## Commands

```bash
npm install
npm run check
npm run test
npm run poc -- doctor
```

Live Hermes PoCs are opt-in and must use an isolated profile:

```bash
npm run poc -- hermes --base-url http://127.0.0.1:8642 --token-env HERMES_API_KEY --prompt "Reply with exactly: ready"
```

## Definition of done

A change is complete when its types compile, relevant offline tests pass, errors identify the failing stage, cancellation remains distinct from failure, and no secret-bearing value appears in test output or logs.
