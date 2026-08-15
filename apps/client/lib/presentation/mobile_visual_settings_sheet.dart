import 'package:flutter/material.dart';

import 'design/agent_talk_theme.dart';
import 'mobile_visual_preferences.dart';

Future<void> showMobileVisualSettingsSheet(
  BuildContext context, {
  required MobileVisualPreferences preferences,
  required Future<void> Function(BuildContext) onOpenVoiceSettings,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
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
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            14,
            0,
            14,
            14 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.panelRaised.withValues(alpha: 0.96),
              border: Border.all(color: tokens.structureLine),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: tokens.shadow, blurRadius: 32)],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _SettingsHeadingOrb(color: tokens.signal),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '视觉设置',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('主题', style: TextStyle(color: tokens.textMuted)),
                  const SizedBox(height: 8),
                  SegmentedButton<MobileVisualTheme>(
                    segments: const [
                      ButtonSegment(
                        value: MobileVisualTheme.dark,
                        label: Text('深色'),
                        icon: Icon(Icons.dark_mode_outlined),
                      ),
                      ButtonSegment(
                        value: MobileVisualTheme.light,
                        label: Text('亮色'),
                        icon: Icon(Icons.light_mode_outlined),
                      ),
                    ],
                    selected: {preferences.theme},
                    onSelectionChanged: (selection) {
                      preferences.setTheme(selection.first);
                    },
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text('文字大小', style: TextStyle(color: tokens.textMuted)),
                      const Spacer(),
                      Text(
                        preferences.fontSize <= 19
                            ? '小号'
                            : preferences.fontSize >= 25
                            ? '大号'
                            : '标准',
                      ),
                    ],
                  ),
                  Slider(
                    min: 18,
                    max: 28,
                    divisions: 10,
                    value: preferences.fontSize,
                    label: preferences.fontSize.round().toString(),
                    onChanged: (value) => preferences.setFontSize(value),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => preferences.setCustomBackgroundPreview(
                      !preferences.customBackgroundPreview,
                    ),
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      preferences.customBackgroundPreview
                          ? '自定义背景预览已启用'
                          : '导入自定义背景（仅视觉预览）',
                    ),
                  ),
                  if (preferences.customBackgroundPreview)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '背景文件仅用于视觉预览，沿用现有本地偏好边界。',
                        style: TextStyle(color: tokens.textMuted),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onOpenVoiceSettings(context);
                    },
                    icon: const Icon(Icons.graphic_eq_outlined),
                    label: const Text('语音与来源设置'),
                  ),
                  if (light)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '亮色主题保留星空结构和状态语义。',
                        style: TextStyle(color: tokens.textMuted),
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

class _SettingsHeadingOrb extends StatelessWidget {
  const _SettingsHeadingOrb({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: const Alignment(-0.45, -0.55),
        colors: [Colors.white, color, context.visualTokens.signalWarm],
        stops: const [0.04, 0.3, 1],
      ),
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 16),
      ],
    ),
  );
}
