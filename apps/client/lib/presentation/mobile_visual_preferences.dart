import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../infrastructure/security/device_key_vault.dart';
import '../infrastructure/security/flutter_secure_value_store.dart';

enum MobileVisualTheme { dark, light }

/// Presentation-only preferences for the mobile visual shell.
///
/// These values deliberately do not become domain state: they only choose the
/// local presentation variant. The existing secure-value port provides the
/// same device-local persistence boundary used by the other client settings.
class MobileVisualPreferences extends ChangeNotifier {
  MobileVisualPreferences({SecureValueStore? store})
    : _store = store ?? FlutterSecureValueStore();

  static const _storageKey = 'voxhandoff.v1.mobile-visual-preferences';

  final SecureValueStore _store;
  MobileVisualTheme _theme = MobileVisualTheme.dark;
  double _fontSize = 21;
  bool _customBackgroundPreview = false;

  MobileVisualTheme get theme => _theme;
  double get fontSize => _fontSize;
  bool get customBackgroundPreview => _customBackgroundPreview;

  Future<void> restore() async {
    try {
      final raw = await _store.read(_storageKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?> || decoded['version'] != 1) {
        return;
      }
      final theme = decoded['theme'];
      final fontSize = decoded['font_size'];
      var changed = false;
      if (theme == MobileVisualTheme.light.name) {
        _theme = MobileVisualTheme.light;
        changed = true;
      } else if (theme == MobileVisualTheme.dark.name) {
        _theme = MobileVisualTheme.dark;
        changed = true;
      }
      if (fontSize is num && fontSize >= 18 && fontSize <= 28) {
        _fontSize = fontSize.toDouble();
        changed = true;
      }
      if (changed) notifyListeners();
    } on Object {
      // A visual preference must never prevent the client from opening.
    }
  }

  Future<void> setTheme(MobileVisualTheme theme) async {
    if (_theme == theme) return;
    _theme = theme;
    notifyListeners();
    await _persist();
  }

  Future<void> setFontSize(double value) async {
    final normalized = value.clamp(18, 28).toDouble();
    if (_fontSize == normalized) return;
    _fontSize = normalized;
    notifyListeners();
    await _persist();
  }

  void setCustomBackgroundPreview(bool enabled) {
    if (_customBackgroundPreview == enabled) return;
    _customBackgroundPreview = enabled;
    notifyListeners();
  }

  Future<void> _persist() => _store.write(
    _storageKey,
    jsonEncode({'version': 1, 'theme': _theme.name, 'font_size': _fontSize}),
  );
}
