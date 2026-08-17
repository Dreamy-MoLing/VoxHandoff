import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/hermes_conversation_controller.dart';
import '../application/manual_connection_controller.dart';
import 'design/agent_talk_theme.dart';
import 'hermes_conversation_settings_sheet.dart';
import 'voice_settings_sheet.dart';

Future<void> showManualConnectionSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ManualConnectionSheet(),
    );

/// 手动连接 fallback（专家路径）。
///
/// 保留现有表单作为手动配置入口（Hermes 对话 / 语音与来源），
/// 并提供 TOFU 门控的连接动作：首次遇到未知指纹时弹出明确风险提示，
/// 不自动接受、不提供"永久忽略"。
class ManualConnectionSheet extends ConsumerStatefulWidget {
  const ManualConnectionSheet({super.key});

  @override
  ConsumerState<ManualConnectionSheet> createState() =>
      _ManualConnectionSheetState();
}

class _ManualConnectionSheetState extends ConsumerState<ManualConnectionSheet> {
  late final TextEditingController _origin;
  late final TextEditingController _model;
  late final TextEditingController _key;

  @override
  void initState() {
    super.initState();
    final current = ref.read(hermesConversationProvider).configuration;
    _origin = TextEditingController(
      text: current?.origin.toString() ?? 'https://',
    );
    _model = TextEditingController(text: current?.model ?? '');
    _key = TextEditingController();
    ref.listenManual(manualConnectionProvider, (previous, next) {
      if (previous?.phase != ManualConnectionPhase.awaitingTofu &&
          next.phase == ManualConnectionPhase.awaitingTofu &&
          next.origin != null &&
          next.fingerprint != null) {
        _showTofuDialog(next.origin!, next.fingerprint!);
      }
    });
  }

  @override
  void dispose() {
    _origin.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _showTofuDialog(String origin, String fingerprint) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => TofuConsentDialog(
        origin: origin,
        fingerprint: fingerprint,
        onAccept: () {
          Navigator.of(dialogContext).pop();
          unawaited(ref.read(manualConnectionProvider.notifier).acceptTofu());
        },
        onCancel: () {
          Navigator.of(dialogContext).pop();
          ref.read(manualConnectionProvider.notifier).cancelTofu();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(manualConnectionProvider);
    final tokens = context.visualTokens;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '手动连接（专家）',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                '默认推荐二维码配对；仅专家使用手动地址。首次遭遇未知服务器指纹时必须显式接受（裸 TOFU），本应用不会自动信任，也不会提供"永久忽略任何服务器"。',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _origin,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'HTTPS Hermes 地址',
                  helperText: '可选 /p/<profile> 路径；信任按主机+指纹记录',
                ),
              ),
              TextField(
                controller: _model,
                decoration: const InputDecoration(labelText: '模型'),
              ),
              TextField(
                controller: _key,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'API key',
                  helperText: '手动连接新端点必须提供 API key；存储在安全存储',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('manual-connect-button'),
                onPressed: state.isBusy ? null : _connect,
                icon: state.isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link),
                label: const Text('连接并信任服务器'),
              ),
              const SizedBox(height: 12),
              if (state.phase == ManualConnectionPhase.probing)
                Text(
                  '正在探测服务器指纹，尚未建立任何信任…',
                  style: TextStyle(color: tokens.attention),
                ),
              if (state.phase == ManualConnectionPhase.connecting)
                Text('正在保存配置…', style: TextStyle(color: tokens.attention)),
              if (state.failureMessage != null &&
                  state.phase == ManualConnectionPhase.failed)
                Text(
                  state.failureMessage!,
                  key: const Key('manual-connect-failure'),
                  style: TextStyle(color: tokens.danger),
                ),
              if (state.infoMessage != null &&
                  (state.phase == ManualConnectionPhase.connected ||
                      state.phase == ManualConnectionPhase.cancelled))
                Text(
                  state.infoMessage!,
                  key: const Key('manual-connect-info'),
                  style: TextStyle(
                    color: state.phase == ManualConnectionPhase.connected
                        ? tokens.signal
                        : tokens.textMuted,
                  ),
                ),
              const Divider(height: 28),
              const Text(
                '手动配置入口（保留现有表单）',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              ListTile(
                key: const Key('manual-open-hermes-form'),
                contentPadding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                leading: Icon(Icons.forum_outlined, color: tokens.signal),
                title: const Text('打开 Hermes 对话设置'),
                subtitle: Text(
                  '地址、模型、API key 的安全保存表单',
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
                onTap: () {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  showHermesConversationSettingsSheet(navigator.context);
                },
              ),
              ListTile(
                key: const Key('manual-open-voice-form'),
                contentPadding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                leading: Icon(Icons.graphic_eq_outlined, color: tokens.signal),
                title: const Text('打开语音与来源设置（STT / TTS）'),
                subtitle: Text(
                  '保留的语音手动配置表单',
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
                onTap: () {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  showVoiceSettingsSheet(navigator.context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _connect() async {
    final origin = Uri.tryParse(_origin.text.trim());
    if (origin == null) return;
    await ref
        .read(manualConnectionProvider.notifier)
        .connectHermes(
          origin: origin,
          model: _model.text.trim(),
          apiKey: _key.text,
        );
  }
}

/// 裸 TOFU 确认对话框：明确说明风险，仅提供"接受"与"取消"，
/// 没有"永久忽略"选项；接受动作本身也不会自动发生。
class TofuConsentDialog extends StatelessWidget {
  const TofuConsentDialog({
    super.key,
    required this.origin,
    required this.fingerprint,
    required this.onAccept,
    required this.onCancel,
  });

  final String origin;
  final String fingerprint;
  final VoidCallback onAccept;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    return AlertDialog(
      backgroundColor: tokens.panelRaised,
      title: const Text('首次连接：接受服务器指纹？'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: tokens.attention),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('目标服务器是本设备第一次见面，它的 TLS 指纹不在任何已知凭据或已导入证书中。'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('目标：', style: TextStyle(fontWeight: FontWeight.w700)),
            SelectableText(origin),
            const SizedBox(height: 12),
            const Text('指纹：', style: TextStyle(fontWeight: FontWeight.w700)),
            SelectableText(
              fingerprint,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              '这是不带带外核验的裸 TOFU：指纹来自服务器自身陈述，没有电脑屏幕等独立确认途径。'
              '若主机被冒名顶替，接受此指纹将无法发现。请核对地址与指纹后决定。',
            ),
            const SizedBox(height: 8),
            const Text(
              '接受只对本主机 + 本指纹生效；其他主机或其他指纹不会被自动信任，也绝不会提供"永久忽略任何服务器"的选项。',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('tofu-cancel'),
          onPressed: onCancel,
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('tofu-accept'),
          onPressed: onAccept,
          child: const Text('接受此指纹并连接'),
        ),
      ],
    );
  }
}
