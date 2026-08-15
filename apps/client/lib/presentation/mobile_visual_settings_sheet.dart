import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design/agent_talk_theme.dart';
import 'mobile_visual_preferences.dart';

Future<void> showMobileVisualSettingsSheet(
  BuildContext context, {
  required MobileVisualPreferences preferences,
  required Future<void> Function(BuildContext) onOpenVoiceSettings,
}) => showDialog<void>(
  context: context,
  barrierColor: Colors.transparent,
  useSafeArea: false,
  builder: (_) => _MobileVisualSettingsSheet(
    preferences: preferences,
    onOpenVoiceSettings: onOpenVoiceSettings,
  ),
);

class _MobileVisualSettingsSheet extends StatelessWidget {
  const _MobileVisualSettingsSheet({
    required this.preferences,
    required this.onOpenVoiceSettings,
  });

  final MobileVisualPreferences preferences;
  final Future<void> Function(BuildContext) onOpenVoiceSettings;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: preferences,
    builder: (context, _) {
      final light = preferences.theme == MobileVisualTheme.light;
      final tokens = context.visualTokens;
      return Material(
        color: tokens.ink,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 34, 18, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 40,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: '返回主页面',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.reply_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _SettingsPageHeading(),
                  const SizedBox(height: 34),
                  _SettingsRow(
                    glyph: Icon(
                      light
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                    title: '主题',
                    value: light ? '亮色' : '深色',
                    trailing: IconButton(
                      tooltip: light ? '切换为深色主题' : '切换为亮色主题',
                      onPressed: () => preferences.setTheme(
                        light
                            ? MobileVisualTheme.dark
                            : MobileVisualTheme.light,
                      ),
                      icon: Icon(
                        light
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SettingsRow(
                    glyph: const Icon(Icons.image_outlined),
                    title: '背景',
                    value: preferences.customBackgroundPreview ? '自定义' : '星空',
                    trailing: IconButton(
                      tooltip: '切换自定义背景预览',
                      onPressed: () => preferences.setCustomBackgroundPreview(
                        !preferences.customBackgroundPreview,
                      ),
                      icon: const Icon(Icons.file_upload_outlined),
                    ),
                  ),
                  if (preferences.customBackgroundPreview)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 56),
                      child: Text(
                        '背景文件仅用于视觉预览，沿用现有本地偏好边界。',
                        style: TextStyle(color: tokens.textMuted),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _SettingsFontRow(preferences: preferences),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onOpenVoiceSettings(context);
                      },
                      icon: const Icon(Icons.graphic_eq_outlined),
                      label: const Text('语音与来源设置'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

String _fontLabel(double size) => size <= 19
    ? '小号'
    : size >= 25
    ? '大号'
    : '标准';

class _SettingsPageHeading extends StatelessWidget {
  const _SettingsPageHeading();

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    return SizedBox(
      width: 108,
      height: 108,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: tokens.signal.withValues(alpha: 0.36)),
              boxShadow: [
                BoxShadow(
                  color: tokens.signal.withValues(alpha: 0.1),
                  blurRadius: 44,
                ),
              ],
            ),
            child: const SizedBox.expand(),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.45, -0.55),
                colors: [Colors.white, tokens.signal, tokens.signalWarm],
                stops: const [0.07, 0.3, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: tokens.signal.withValues(alpha: 0.44),
                  blurRadius: 22,
                ),
              ],
            ),
          ),
          Container(
            width: 76,
            height: 1,
            color: tokens.signal.withValues(alpha: 0.34),
            transform: Matrix4.rotationZ(44 * math.pi / 180),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.glyph,
    required this.title,
    required this.value,
    required this.trailing,
  });

  final Widget glyph;
  final String title;
  final String value;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.panel.withValues(alpha: 0.8),
        border: Border.all(color: tokens.structureLine),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow.withValues(alpha: 0.6),
            blurRadius: 28,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.signal.withValues(alpha: 0.08),
              border: Border.all(color: tokens.signal.withValues(alpha: 0.32)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconTheme(
              data: IconThemeData(color: tokens.signal),
              child: glyph,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, letterSpacing: 0.08),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 12,
                    letterSpacing: 0.06,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _SettingsFontRow extends StatelessWidget {
  const _SettingsFontRow({required this.preferences});

  final MobileVisualPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.panel.withValues(alpha: 0.8),
        border: Border.all(color: tokens.structureLine),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow.withValues(alpha: 0.6),
            blurRadius: 28,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.signal.withValues(alpha: 0.08),
              border: Border.all(color: tokens.signal.withValues(alpha: 0.32)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconTheme(
              data: IconThemeData(color: tokens.signal),
              child: const Text(
                'A',
                style: TextStyle(fontFamily: 'Georgia', fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '文字大小',
                  style: const TextStyle(fontSize: 14, letterSpacing: 0.08),
                ),
                const SizedBox(height: 4),
                Text(
                  _fontLabel(preferences.fontSize),
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 12,
                    letterSpacing: 0.06,
                  ),
                ),
                SizedBox(
                  height: 32,
                  child: Slider(
                    min: 18,
                    max: 28,
                    divisions: 10,
                    value: preferences.fontSize,
                    label: preferences.fontSize.round().toString(),
                    onChanged: preferences.setFontSize,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
