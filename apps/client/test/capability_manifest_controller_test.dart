import 'package:agent_talk_client/application/capability_manifest_controller.dart';
import 'package:agent_talk_client/domain/capability_manifest.dart';
import 'package:agent_talk_client/infrastructure/manifest/capability_manifest_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sampleManifest = CapabilityManifest(
    chat: ManifestChatSection(available: true),
    stt: ManifestSttSection(available: true),
    tts: ManifestTtsSection(available: true, recommendedVoice: 'Bronya'),
    hermes: ManifestHermesSection(available: true, profile: 'p', model: 'm'),
  );

  ProviderContainer containerWith(FakeManifestRepository repository) {
    final container = ProviderContainer(
      overrides: [
        capabilityManifestRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('refresh 成功进入 ready 并携带 manifest', () async {
    final repository = FakeManifestRepository(manifest: sampleManifest);
    final container = containerWith(repository);
    final controller = container.read(capabilityManifestProvider.notifier);

    expect(
      container.read(capabilityManifestProvider).phase,
      ManifestRefreshPhase.idle,
    );

    await controller.refresh();

    final state = container.read(capabilityManifestProvider);
    expect(state.phase, ManifestRefreshPhase.ready);
    expect(state.manifest?.chat.available, isTrue);
    expect(state.manifest?.tts.recommendedVoice, 'Bronya');
    expect(state.failureMessage, isNull);
    expect(state.lastRefreshedAt, isNotNull);
  });

  test('刷新失败降级为可读错误，manifest 不变', () async {
    final repository = FakeManifestRepository(
      failure: const ManifestFetchException(
        'bridge_not_configured',
        '未完成配对，无法获取能力清单。',
      ),
    );
    final container = containerWith(repository);
    final controller = container.read(capabilityManifestProvider.notifier);

    await controller.refresh();

    final state = container.read(capabilityManifestProvider);
    expect(state.phase, ManifestRefreshPhase.failed);
    expect(state.failureCode, 'bridge_not_configured');
    expect(state.failureMessage, contains('未完成配对'));
    expect(state.manifest, isNull);
  });

  test('未知异常也收敛为可读错误，不让异常逃逸', () async {
    final repository = FakeManifestRepository(thrown: StateError('boom'));
    final container = containerWith(repository);
    final controller = container.read(capabilityManifestProvider.notifier);

    await controller.refresh();

    final state = container.read(capabilityManifestProvider);
    expect(state.phase, ManifestRefreshPhase.failed);
    expect(state.failureCode, 'manifest_fetch_failed');
    expect(state.failureMessage, isNotNull);
  });

  test('进行中的刷新被忽略，不会叠加请求', () async {
    final repository = FakeManifestRepository(manifest: sampleManifest);
    final container = containerWith(repository);
    final controller = container.read(capabilityManifestProvider.notifier);

    final first = controller.refresh();
    final second = controller.refresh();
    await Future.wait([first, second]);

    expect(repository.fetchCount, 1);
    expect(
      container.read(capabilityManifestProvider).phase,
      ManifestRefreshPhase.ready,
    );
  });

  test('失败后再次 refresh 可恢复 ready', () async {
    final repository = FakeManifestRepository(manifest: sampleManifest)
      ..armFailures(1);
    final container = containerWith(repository);
    final controller = container.read(capabilityManifestProvider.notifier);

    await controller.refresh();
    expect(
      container.read(capabilityManifestProvider).phase,
      ManifestRefreshPhase.failed,
    );

    await controller.refresh();
    expect(
      container.read(capabilityManifestProvider).phase,
      ManifestRefreshPhase.ready,
    );
    expect(
      container.read(capabilityManifestProvider).manifest?.chat.available,
      isTrue,
    );
  });
}

class FakeManifestRepository implements CapabilityManifestRepository {
  FakeManifestRepository({this.manifest, this.failure, this.thrown});

  final CapabilityManifest? manifest;
  final ManifestFetchException? failure;
  final Object? thrown;
  int fetchCount = 0;
  int _failuresLeft = 0;

  @override
  Future<CapabilityManifest> fetch() {
    fetchCount += 1;
    if (_failuresLeft > 0) {
      _failuresLeft -= 1;
      return Future.error(
        failure ?? const ManifestFetchException('boom', 'boom'),
      );
    }
    if (thrown != null) return Future.error(thrown!);
    if (failure != null) return Future.error(failure!);
    return Future.value(manifest ?? const CapabilityManifest());
  }

  void armFailures(int count) => _failuresLeft = count;
}
