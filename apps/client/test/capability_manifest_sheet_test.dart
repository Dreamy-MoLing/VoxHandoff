import 'dart:async';

import 'package:agent_talk_client/application/capability_manifest_controller.dart';
import 'package:agent_talk_client/domain/capability_manifest.dart';
import 'package:agent_talk_client/infrastructure/manifest/capability_manifest_repository.dart';
import 'package:agent_talk_client/presentation/capability_manifest_sheet.dart';
import 'package:agent_talk_client/presentation/design/agent_talk_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildApp({required CapabilityManifestRepository repository}) {
    return ProviderScope(
      overrides: [
        capabilityManifestRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: buildAgentTalkMobileDarkTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showCapabilityManifestSheet(context),
                child: const Text('打开总览'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('展示 design 示例：Hermes / 语音识别 / 声音 全部可用', (tester) async {
    final repository = FakeManifestRepository(
      manifest: CapabilityManifest.fromJsonString('''
      {
        "chat": { "available": true },
        "stt": { "available": true, "capabilities": { } },
        "tts": { "available": true, "voices": [ ], "recommended_voice": "Bronya" },
        "hermes": { "profile": "p", "model": "m" }
      }
      '''),
    );
    await tester.pumpWidget(buildApp(repository: repository));
    await tester.tap(find.text('打开总览'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('manifest-row-hermes')), findsOneWidget);
    expect(find.text('✓ 可用'), findsNWidgets(2));
    expect(find.text('✓ Bronya'), findsOneWidget);
    expect(repository.fetchCount, 1);
  });

  testWidgets('STT 缺失显示语音输入未配置、TTS 缺失显示文字正常工作', (tester) async {
    final repository = FakeManifestRepository(
      manifest: CapabilityManifest.fromJsonString('''
      {
        "chat": { "available": true },
        "stt": { "available": false },
        "tts": { "available": false }
      }
      '''),
    );
    await tester.pumpWidget(buildApp(repository: repository));
    await tester.tap(find.text('打开总览'));
    await tester.pumpAndSettle();

    expect(find.text('语音输入未配置'), findsWidgets);
    expect(find.text('文字正常工作'), findsOneWidget);
    expect(find.text('✓ 可用'), findsOneWidget);
  });

  testWidgets('Hermes Chat 不可用时提示不可用', (tester) async {
    final repository = FakeManifestRepository(
      manifest: CapabilityManifest.fromJsonString('''
      {
        "chat": { "available": false },
        "stt": { "available": true },
        "tts": { "available": true }
      }
      '''),
    );
    await tester.pumpWidget(buildApp(repository: repository));
    await tester.tap(find.text('打开总览'));
    await tester.pumpAndSettle();

    expect(find.text('不可用'), findsWidgets);
    expect(find.textContaining('Hermes Chat 必须可用'), findsOneWidget);
  });

  testWidgets('刷新失败降级为可读错误', (tester) async {
    final repository = FakeManifestRepository(
      failure: const ManifestFetchException(
        'bridge_not_configured',
        '未完成配对，无法获取能力清单。完成配对后重试即可；这不影响文字输入。',
      ),
    );
    await tester.pumpWidget(buildApp(repository: repository));
    await tester.tap(find.text('打开总览'));
    await tester.pumpAndSettle();

    expect(find.text('能力清单获取失败。'), findsOneWidget);
    expect(find.byKey(const Key('manifest-failure-message')), findsOneWidget);
    expect(find.textContaining('未完成配对'), findsOneWidget);
  });

  testWidgets('加载中显示等待提示并可手动刷新', (tester) async {
    final gate = Completer<void>();
    final repository = FakeManifestRepository(
      manifest: const CapabilityManifest(),
    )..beforeResolve = gate.future;
    await tester.pumpWidget(buildApp(repository: repository));
    await tester.tap(find.text('打开总览'));
    await tester.pump();
    await tester.pump();

    expect(find.text('正在获取能力清单…'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('manifest-refresh-button')))
          .onPressed,
      isNull,
    );

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('正在获取能力清单…'), findsNothing);
  });

  testWidgets('高级默认收拢，展开后显示手动配置入口', (tester) async {
    final repository = FakeManifestRepository(
      manifest: CapabilityManifest.fromJsonString('''
      {
        "chat": { "available": true },
        "stt": { "available": true },
        "tts": { "available": true, "recommended_voice": "Bronya" }
      }
      '''),
    );
    await tester.pumpWidget(buildApp(repository: repository));
    await tester.tap(find.text('打开总览'));
    await tester.pumpAndSettle();

    final tile = tester.widget<ExpansionTile>(
      find.byKey(const Key('advanced-manual-config')),
    );
    expect(tile.initiallyExpanded, isFalse);
    expect(find.text('Hermes 对话设置'), findsNothing);

    await tester.tap(find.byKey(const Key('advanced-manual-config')));
    await tester.pumpAndSettle();

    expect(find.text('Hermes 对话设置'), findsOneWidget);
    expect(find.text('Direct LLM 设置'), findsOneWidget);
    expect(find.text('语音与来源设置（STT / TTS）'), findsOneWidget);
  });

  testWidgets('高级中的 Hermes 设置沿用现有表单', (tester) async {
    final repository = FakeManifestRepository(
      manifest: CapabilityManifest.fromJsonString('''
      {
        "chat": { "available": true },
        "stt": { "available": true },
        "tts": { "available": true, "recommended_voice": "Bronya" }
      }
      '''),
    );
    await tester.pumpWidget(buildApp(repository: repository));
    await tester.tap(find.text('打开总览'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('advanced-manual-config')));
    await tester.tap(find.byKey(const Key('advanced-manual-config')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('advanced-hermes-conversation')),
    );
    await tester.tap(find.byKey(const Key('advanced-hermes-conversation')));
    await tester.pumpAndSettle();

    expect(find.text('Hermes 对话'), findsOneWidget);
    expect(find.text('模型'), findsOneWidget);
  });
}

class FakeManifestRepository implements CapabilityManifestRepository {
  FakeManifestRepository({this.manifest, this.failure});

  final CapabilityManifest? manifest;
  final ManifestFetchException? failure;
  int fetchCount = 0;
  Future<void>? beforeResolve;

  @override
  Future<CapabilityManifest> fetch() async {
    fetchCount += 1;
    if (beforeResolve != null) await beforeResolve;
    if (failure != null) throw failure!;
    return manifest ?? const CapabilityManifest();
  }
}
