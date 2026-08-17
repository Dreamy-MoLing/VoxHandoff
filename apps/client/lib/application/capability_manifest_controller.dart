import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/capability_manifest.dart';
import '../infrastructure/manifest/capability_manifest_repository.dart';

/// Manifest 获取源；默认是 Bridge 未就绪的降级实现，测试中可注入 fake。
final capabilityManifestRepositoryProvider =
    Provider<CapabilityManifestRepository>(
      (_) => const UnavailableCapabilityManifestRepository(),
    );

final capabilityManifestProvider =
    NotifierProvider<CapabilityManifestController, CapabilityManifestState>(
      CapabilityManifestController.new,
    );

enum ManifestRefreshPhase { idle, loading, ready, failed }

class CapabilityManifestState {
  const CapabilityManifestState({
    this.phase = ManifestRefreshPhase.idle,
    this.manifest,
    this.failureCode,
    this.failureMessage,
    this.lastRefreshedAt,
  });

  final ManifestRefreshPhase phase;
  final CapabilityManifest? manifest;
  final String? failureCode;
  final String? failureMessage;
  final DateTime? lastRefreshedAt;

  bool get isLoading => phase == ManifestRefreshPhase.loading;

  CapabilityManifestState copyWith({
    ManifestRefreshPhase? phase,
    CapabilityManifest? manifest,
    String? failureCode,
    String? failureMessage,
    DateTime? lastRefreshedAt,
  }) => CapabilityManifestState(
    phase: phase ?? this.phase,
    manifest: manifest ?? this.manifest,
    failureCode: failureCode ?? this.failureCode,
    failureMessage: failureMessage ?? this.failureMessage,
    lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
  );

  CapabilityManifestState beginRefresh() => CapabilityManifestState(
    phase: ManifestRefreshPhase.loading,
    manifest: manifest,
  );

  CapabilityManifestState finishSuccess(CapabilityManifest next) => copyWith(
    phase: ManifestRefreshPhase.ready,
    manifest: next,
    failureCode: null,
    failureMessage: null,
    lastRefreshedAt: DateTime.now(),
  );

  CapabilityManifestState finishFailure(String code, String message) =>
      copyWith(
        phase: ManifestRefreshPhase.failed,
        failureCode: code,
        failureMessage: message,
      );
}

/// Manifest 刷新与展示逻辑。刷新失败只降级为可读错误，
/// 状态完全隔离，不会阻塞或改变文字主链路。
class CapabilityManifestController extends Notifier<CapabilityManifestState> {
  var _refreshInFlight = false;

  @override
  CapabilityManifestState build() => const CapabilityManifestState();

  Future<void> refresh() async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    state = state.beginRefresh();
    final repository = ref.read(capabilityManifestRepositoryProvider);
    try {
      final manifest = await repository.fetch();
      state = state.finishSuccess(manifest);
    } on ManifestFetchException catch (error) {
      state = state.finishFailure(error.code, error.safeMessage);
    } on Object {
      state = state.finishFailure(
        'manifest_fetch_failed',
        '获取能力清单失败。文字输入不受影响，可稍后再试。',
      );
    } finally {
      _refreshInFlight = false;
    }
  }
}
