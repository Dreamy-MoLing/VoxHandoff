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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.tune_outlined,
                      color: context.visualTokens.signal,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Visual settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Theme',
                  style: TextStyle(color: context.visualTokens.textMuted),
                ),
                const SizedBox(height: 8),
                SegmentedButton<MobileVisualTheme>(
                  segments: const [
                    ButtonSegment(
                      value: MobileVisualTheme.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                    ButtonSegment(
                      value: MobileVisualTheme.light,
                      label: Text('Light'),
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
                    Text(
                      'Text size',
                      style: TextStyle(color: context.visualTokens.textMuted),
                    ),
                    const Spacer(),
                    Text(
                      preferences.fontSize <= 19
                          ? 'Small'
                          : preferences.fontSize >= 25
                          ? 'Large'
                          : 'Standard',
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
                        ? 'Sample background enabled'
                        : 'Import custom background (visual preview)',
                  ),
                ),
                if (preferences.customBackgroundPreview)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Visual entry only; background-file persistence awaits product confirmation.',
                      style: TextStyle(color: context.visualTokens.textMuted),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onOpenVoiceSettings(context);
                  },
                  icon: const Icon(Icons.graphic_eq_outlined),
                  label: const Text('Voice and source settings'),
                ),
                if (light)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Light mode keeps the starfield signal structure and state semantics.',
                      style: TextStyle(color: context.visualTokens.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
