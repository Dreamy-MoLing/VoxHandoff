# VoxHandoff client

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
