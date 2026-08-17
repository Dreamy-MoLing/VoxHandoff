import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/hermes_conversation.dart';
import '../infrastructure/security/flutter_secure_value_store.dart';
import '../infrastructure/security/server_fingerprint_probe.dart';
import '../infrastructure/security/tofu_trust_store.dart';
import 'hermes_conversation_controller.dart';

final fingerprintProbeProvider = Provider<FingerprintProbe>(
  (_) => ServerFingerprintProbe(),
);

final tofuTrustStoreProvider = Provider<TofuTrustStore>(
  (_) => SecureTofuTrustStore(FlutterSecureValueStore()),
);

final manualConnectionProvider =
    NotifierProvider<ManualConnectionController, ManualConnectionState>(
      ManualConnectionController.new,
    );

enum ManualConnectionPhase {
  idle,
  probing,
  awaitingTofu,
  connecting,
  connected,
  failed,
  cancelled,
}

class ManualConnectionState {
  const ManualConnectionState({
    this.phase = ManualConnectionPhase.idle,
    this.origin,
    this.fingerprint,
    this.failureCode,
    this.failureMessage,
    this.infoMessage,
  });

  final ManualConnectionPhase phase;
  final String? origin;
  final String? fingerprint;
  final String? failureCode;
  final String? failureMessage;
  final String? infoMessage;

  bool get isBusy =>
      phase == ManualConnectionPhase.probing ||
      phase == ManualConnectionPhase.connecting;

  ManualConnectionState copyWith({
    ManualConnectionPhase? phase,
    String? origin,
    String? fingerprint,
    String? failureCode,
    String? failureMessage,
    String? infoMessage,
  }) => ManualConnectionState(
    phase: phase ?? this.phase,
    origin: origin ?? this.origin,
    fingerprint: fingerprint ?? this.fingerprint,
    failureCode: failureCode ?? this.failureCode,
    failureMessage: failureMessage ?? this.failureMessage,
    infoMessage: infoMessage ?? this.infoMessage,
  );
}

/// 手动连接 fallback：保留现有表单入口作为手动配置；连接前探测服务器
/// 指纹，未知指纹必须由用户显式接受（裸 TOFU）后才保存配置——
/// 不自动接受、不提供"永久忽略"。
class ManualConnectionController extends Notifier<ManualConnectionState> {
  Uri? _requestedOrigin;
  String? _requestedModel;
  String? _requestedKey;
  String? _displayedFingerprint;

  @override
  ManualConnectionState build() => const ManualConnectionState();

  Future<void> connectHermes({
    required Uri origin,
    required String model,
    required String apiKey,
  }) async {
    _requestedOrigin = origin;
    _requestedModel = model.trim();
    _requestedKey = apiKey;
    if (!_validateInputs()) return;

    final bare = _bareServer(origin);
    state = state.copyWith(
      phase: ManualConnectionPhase.probing,
      origin: bare.toString(),
    );
    try {
      final fingerprint = await ref.read(fingerprintProbeProvider).probe(bare);
      final trusted = await ref
          .read(tofuTrustStoreProvider)
          .isTrusted(origin, fingerprint);
      if (trusted) {
        _displayedFingerprint = fingerprint;
        await _commit();
        return;
      }
      _displayedFingerprint = fingerprint;
      state = state.copyWith(
        phase: ManualConnectionPhase.awaitingTofu,
        fingerprint: fingerprint,
      );
    } on FingerprintProbeException catch (error) {
      state = state.copyWith(
        phase: ManualConnectionPhase.failed,
        failureCode: error.code,
        failureMessage: error.safeMessage,
      );
    } on Object {
      state = state.copyWith(
        phase: ManualConnectionPhase.failed,
        failureCode: 'manual_connect_failed',
        failureMessage: '手动连接失败，原配置未改变。',
      );
    }
  }

  /// 用户显式接受未知指纹。接受前重新探测：指纹一旦变化就 fail closed，
  /// 不建立信任、不保存配置。
  Future<void> acceptTofu() async {
    final origin = _requestedOrigin;
    final fingerprint = _displayedFingerprint;
    if (origin == null ||
        fingerprint == null ||
        state.phase != ManualConnectionPhase.awaitingTofu) {
      return;
    }
    try {
      final live = await ref
          .read(fingerprintProbeProvider)
          .probe(_bareServer(origin));
      if (live != fingerprint) {
        state = state.copyWith(
          phase: ManualConnectionPhase.failed,
          failureCode: 'tofu_fingerprint_changed',
          failureMessage: '服务器指纹与刚才不一致，连接已停止。请核对地址后重试。',
        );
        return;
      }
      await ref.read(tofuTrustStoreProvider).record(origin, fingerprint);
    } on FingerprintProbeException catch (error) {
      state = state.copyWith(
        phase: ManualConnectionPhase.failed,
        failureCode: error.code,
        failureMessage: error.safeMessage,
      );
      return;
    } on Object {
      state = state.copyWith(
        phase: ManualConnectionPhase.failed,
        failureCode: 'tofu_accept_failed',
        failureMessage: '无法确认服务器指纹，未建立任何信任。',
      );
      return;
    }
    await _commit();
  }

  void cancelTofu() {
    if (state.phase != ManualConnectionPhase.awaitingTofu) return;
    _displayedFingerprint = null;
    state = state.copyWith(
      phase: ManualConnectionPhase.cancelled,
      fingerprint: null,
      infoMessage: '已取消，未保存任何信任或配置。',
    );
  }

  void reset() {
    _displayedFingerprint = null;
    state = const ManualConnectionState();
  }

  bool _validateInputs() {
    final origin = _requestedOrigin;
    final model = _requestedModel;
    final apiKey = _requestedKey;
    if (origin == null ||
        origin.scheme.toLowerCase() != 'https' ||
        origin.host.isEmpty) {
      state = state.copyWith(
        phase: ManualConnectionPhase.failed,
        failureCode: 'manual_invalid_origin',
        failureMessage: '请输入 HTTPS 地址，且不带查询参数或片段。',
      );
      return false;
    }
    if (model == null || model.isEmpty || model.length > 256) {
      state = state.copyWith(
        phase: ManualConnectionPhase.failed,
        failureCode: 'manual_invalid_model',
        failureMessage: '请输入不超过 256 字符的模型名。',
      );
      return false;
    }
    if (apiKey == null || apiKey.trim().isEmpty) {
      state = state.copyWith(
        phase: ManualConnectionPhase.failed,
        failureCode: 'manual_key_required',
        failureMessage: '手动连接新端点需要提供 API key。',
      );
      return false;
    }
    return true;
  }

  Future<void> _commit() async {
    final origin = _requestedOrigin;
    final model = _requestedModel;
    if (origin == null || model == null) return;
    state = state.copyWith(phase: ManualConnectionPhase.connecting);
    final configuration = HermesConversationConfiguration(
      providerProfileId: 'manual-connection',
      origin: origin,
      model: model,
      conversationId: 'manual-conversation',
      sessionId: 'manual-session',
      sessionKey: 'manual-scope',
      sessionIdPolicy: HermesSessionIdPolicy.generatedStable,
    );
    await ref
        .read(hermesConversationProvider.notifier)
        .configure(configuration, _requestedKey?.trim() ?? '');
    if (ref.read(hermesConversationProvider).isConfigured) {
      state = state.copyWith(
        phase: ManualConnectionPhase.connected,
        infoMessage: '已保存手动连接并信任服务器；链接将沿用现有主链路行为。',
      );
    } else {
      final failure = ref.read(hermesConversationProvider).failure;
      state = state.copyWith(
        phase: ManualConnectionPhase.failed,
        failureCode: 'manual_save_rejected',
        failureMessage: failure?.message ?? '配置未通过安全检查，未保存。',
      );
    }
  }

  Uri _bareServer(Uri origin) => Uri(
    scheme: origin.scheme,
    host: origin.host,
    port: origin.hasPort ? origin.port : 443,
  );
}
