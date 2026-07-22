# VoxHandoff repository guide

## Product contract

VoxHandoff is a voice relay for local and remote coding/automation agents. It records locally, produces editable text, sends only confirmed text to an explicitly selected Agent, preserves the complete Agent reply, and optionally speaks a separate short summary.

`spec/` is the only active product and engineering baseline:

- `spec/PRODUCT.md` defines product behavior and acceptance targets;
- `spec/ARCHITECTURE.md` defines technical and security boundaries;
- `spec/DELIVERY.md` defines milestones, tests, release gates, and the current evidence state.

The root `docs/` directory contains absorbed pre-development research. It is ignored by Git and must not be used as a current requirement source or referenced by new code, tests, issues, or documents.

## Non-negotiable behavior

- Never auto-approve an Agent permission, clarification, secret, sudo, deletion, publishing, payment, or authorization request.
- Never silently retry a submission whose remote acceptance is uncertain.
- Keep full text independent from STT, summary generation, TTS, and audio playback failures.
- Reject stale events by connection/session/request identity and monotonic sequence.
- Keep raw recordings local by default and redact secrets from logs and diagnostic exports.
- Do not expose Codex app-server or an unauthenticated Agent endpoint directly to a public network.

## Architecture boundaries

- `packages/core`: dependency-free domain types, lifecycle/state machine, redaction, and deterministic speech-summary rules.
- `packages/adapters`: protocol-specific Agent clients. Translate native events into `@agent-talk/core`; never leak native protocol details into UI state.
- `apps/poc-cli`: executable protocol and failure-injection PoCs. This is the acceptance harness, not a disposable demo.
- Future `apps/client`: Flutter UI shared by desktop and mobile. Desktop host starts only the bundled sidecar; mobile never receives local process capabilities.
- Future `services/stt`: optional Python sidecar behind a versioned local HTTP/stdio contract. The desktop must still work with remote STT or no STT.
- Future `services/gateway` and `services/node`: authenticated gRPC control plane, PostgreSQL event ledger, and outbound Agent-host connector as specified in `spec/ARCHITECTURE.md`.

## Development rules

- TypeScript is strict; avoid `any` at protocol boundaries. Parse untrusted payloads from `unknown` with small guards.
- Prefer Node built-ins in protocol code. Add dependencies only when they materially improve correctness or portability.
- Prefer official protocols and mature community components. Record license, platform coverage, maintenance evidence, and an exit path for each infrastructure dependency.
- Keep adapter tests offline with fixtures/fakes. Live tests must be explicit and must not mutate user data without a clear prompt.
- Generate Codex bindings from the installed CLI in a temporary version-specific directory and run `npm run protocol:codex`; do not hand-edit or commit bulky generated files.
- Use opaque IDs. Do not derive security decisions from display labels.

## Commands

```bash
npm install
npm run check
npm run test
npm run poc -- doctor
```

Live PoCs are opt-in:

```bash
npm run poc -- codex --prompt "Reply with exactly: ready"
npm run poc -- hermes --base-url http://127.0.0.1:8642 --token-env HERMES_API_KEY --prompt "Reply with exactly: ready"
```

## Definition of done

A change is complete when its types compile, relevant offline tests pass, errors identify the failing stage, cancellation remains distinct from failure, and no secret-bearing value appears in test output or logs.
