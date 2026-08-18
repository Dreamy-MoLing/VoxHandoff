# VoxHandoff client

> **文档分工：** 本文件面向使用者和开发者，说明客户端用途、支持范围与基本验证方式；`AGENTS.md` 面向 Agent，规定 `apps/client/**` 的实现边界和完成门。

Flutter client shared by Windows, Linux, macOS, iOS, and Android.

The application layer owns only transient view state. Confirmed text, request
identity, events, approvals, and cursors become authoritative only through the
Gateway contracts in `agent_talk_protocol`; Riverpod providers are not a durable
ledger. The initial shell therefore keeps sending disabled until pairing,
credential storage, and the Gateway transport are connected.

Use Flutter 3.44.6 / Dart 3.12.2:

```bash
flutter pub get
flutter analyze
flutter test
```

From the repository root, `npm run flutter:check` runs the generated protocol
analysis and both client gates. Set `AGENT_TALK_FLUTTER_ROOT` when the pinned SDK
is not on `PATH`.

Linux native builds additionally require Clang and GTK 3 development headers.

## Android-first MVP

The current delivery target is Android foreground use only. The release
manifest must retain both `INTERNET` for HTTPS Gateway/Direct LLM traffic and
`RECORD_AUDIO` for the consented tap-to-talk path. Android never starts the
Node, Hermes, Gateway, PostgreSQL, or local STT sidecar processes; it connects
to a remote authenticated Gateway or directly to the user's configured LLM.

The Android MVP is not accepted from a debug APK alone. A release-variant
artifact, a real device pairing/reconnect check, secure-storage read-back,
permission denial behavior, and one text-first voice turn remain required.

For the voice turn, Android uses the explicit-consent HTTPS STT variant: the
provider origin, TLS policy, retention disclosure, and contract revision are
stored as ordinary configuration while the provider token is kept separately
in OS-backed secure storage. Audio is buffered in memory and uploaded only
after the foreground recording is stopped. A fake transport or a passing
Flutter test does not close the real provider, TLS, retention, or device gate.
