import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/capability_manifest_controller.dart';
import '../domain/capability_manifest.dart';
import 'design/agent_talk_theme.dart';
import 'direct_llm_settings_sheet.dart';
import 'hermes_conversation_settings_sheet.dart';
import 'manual_connection_sheet.dart';
import 'voice_settings_sheet.dart';

Future<void> showCapabilityManifestSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CapabilityManifestSheet(),
    );

/// 配对后状态总览：Hermes / 语音识别 / 声音，按 manifest 显示。
/// 刷新失败仅降级为可读错误，不影响文字主链路。
class CapabilityManifestSheet extends ConsumerStatefulWidget {
  const CapabilityManifestSheet({super.key});

  @override
  ConsumerState<CapabilityManifestSheet> createState() =>
      _CapabilityManifestSheetState();
}

class _CapabilityManifestSheetState
    extends ConsumerState<CapabilityManifestSheet> {
  @override
  void initState() {
    super.initState();
    // 配对后语义：打开总览即拉取一次；失败由面板内降级展示。
    // 延迟到 build/initState 之外写入 provider 状态。
    Future<void>.microtask(
      () => ref.read(capabilityManifestProvider.notifier).refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(capabilityManifestProvider);
    final manifest = state.manifest;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '连接与能力',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('manifest-refresh-button'),
                    tooltip: '刷新能力清单',
                    onPressed: state.isLoading
                        ? null
                        : () => unawaited(
                            ref
                                .read(capabilityManifestProvider.notifier)
                                .refresh(),
                          ),
                    icon: state.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('配对后由 Companion Bridge 下发。本面板失败只影响能力总览，不影响文字或语音主链路。'),
              const SizedBox(height: 16),
              if (manifest == null) ...[
                Text(
                  state.phase == ManifestRefreshPhase.loading
                      ? '正在获取能力清单…'
                      : state.phase == ManifestRefreshPhase.failed
                      ? '能力清单获取失败。'
                      : '尚未获取能力清单，配对后自动显示。',
                  key: const Key('manifest-overview-unavailable'),
                  style: TextStyle(color: context.visualTokens.textMuted),
                ),
              ] else ...[
                _CapabilityRow(
                  key: const Key('manifest-row-hermes'),
                  glyph: Icons.forum_outlined,
                  title: 'Hermes 对话',
                  available: manifest.chatAvailable,
                  availableValue: '✓ 可用',
                  unavailableValue: '不可用',
                  note: manifest.chatAvailable
                      ? '文字主链路可用'
                      : 'Hermes Chat 必须可用；当前不可用，文字主链路无法使用。',
                ),
                _CapabilityRow(
                  key: const Key('manifest-row-stt'),
                  glyph: Icons.mic_outlined,
                  title: '语音识别',
                  available: manifest.sttAvailable,
                  availableValue: '✓ 可用',
                  unavailableValue: '语音输入未配置',
                  note: manifest.sttAvailable ? null : '语音输入未配置，可继续使用文字输入。',
                ),
                _CapabilityRow(
                  key: const Key('manifest-row-tts'),
                  glyph: Icons.volume_up_outlined,
                  title: '声音',
                  available: manifest.ttsAvailable,
                  availableValue: _ttsVoiceLabel(manifest.tts),
                  unavailableValue: '文字正常工作',
                  note: manifest.ttsAvailable ? null : '声音缺失时文字正常工作。',
                ),
                if (state.lastRefreshedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      '已更新 ${_formatTime(state.lastRefreshedAt!)}',
                      style: TextStyle(
                        color: context.visualTokens.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
              if (state.failureMessage != null &&
                  state.phase == ManifestRefreshPhase.failed) ...[
                const SizedBox(height: 12),
                _FailureBanner(message: state.failureMessage!),
              ],
              const Divider(height: 32),
              const _AdvancedManualConfigSection(),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}

/// 高级折叠：默认收拢；展开后保留现有手动配置表单入口
/// （Hermes 对话 / Direct LLM / 语音与来源 STT·TTS）。
class _AdvancedManualConfigSection extends StatelessWidget {
  const _AdvancedManualConfigSection();

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    return ExpansionTile(
      key: const Key('advanced-manual-config'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(top: 4),
      initiallyExpanded: false,
      title: const Text('高级', style: TextStyle(fontWeight: FontWeight.w700)),
      subtitle: const Text('手动配置与连接（专家）'),
      iconColor: tokens.signal,
      collapsedIconColor: tokens.textMuted,
      children: [
        _ManualEntry(
          key: const Key('advanced-hermes-conversation'),
          glyph: Icons.forum_outlined,
          title: 'Hermes 对话设置',
          subtitle: '主链路手动配置：HTTPS 地址、模型、API key',
          onTap: () =>
              _openAfterClose(context, showHermesConversationSettingsSheet),
        ),
        _ManualEntry(
          key: const Key('advanced-direct-llm'),
          glyph: Icons.key_outlined,
          title: 'Direct LLM 设置',
          subtitle: '延后可选能力，独立于 Hermes 主链路',
          onTap: () => _openAfterClose(context, showDirectLlmSettingsSheet),
        ),
        _ManualEntry(
          key: const Key('advanced-voice-settings'),
          glyph: Icons.graphic_eq_outlined,
          title: '语音与来源设置（STT / TTS）',
          subtitle: '本地或已同意远程的语音服务手动配置',
          onTap: () => _openAfterClose(context, showVoiceSettingsSheet),
        ),
        _ManualEntry(
          key: const Key('advanced-manual-connection'),
          glyph: Icons.link,
          title: '手动连接（专家）',
          subtitle: '手动输入地址后首次接受未知指纹需显式 TOFU 确认',
          onTap: () => _openAfterClose(context, showManualConnectionSheet),
        ),
      ],
    );
  }

  void _openAfterClose(
    BuildContext context,
    Future<void> Function(BuildContext) opener,
  ) {
    final navigator = Navigator.of(context);
    navigator.pop();
    opener(navigator.context);
  }
}

class _ManualEntry extends StatelessWidget {
  const _ManualEntry({
    super.key,
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData glyph;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      leading: Icon(glyph, color: tokens.signal, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: tokens.textMuted, fontSize: 12),
      ),
      onTap: onTap,
    );
  }
}

String _ttsVoiceLabel(ManifestTtsSection tts) {
  final recommended = tts.recommendedVoice;
  if (recommended != null && recommended.isNotEmpty) {
    return '✓ $recommended';
  }
  if (tts.voices.isNotEmpty) return '✓ ${tts.voices.first}';
  return '✓ 可用';
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({
    super.key,
    required this.glyph,
    required this.title,
    required this.available,
    required this.availableValue,
    required this.unavailableValue,
    this.note,
  });

  final IconData glyph;
  final String title;
  final bool available;
  final String availableValue;
  final String unavailableValue;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            glyph,
            size: 20,
            color: available ? tokens.signal : tokens.danger,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      note!,
                      style: TextStyle(color: tokens.textMuted, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            available ? availableValue : unavailableValue,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: available ? tokens.signal : tokens.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.danger.withValues(alpha: 0.1),
        border: Border.all(color: tokens.danger.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: tokens.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              key: const Key('manifest-failure-message'),
              style: TextStyle(color: tokens.danger),
            ),
          ),
        ],
      ),
    );
  }
}
