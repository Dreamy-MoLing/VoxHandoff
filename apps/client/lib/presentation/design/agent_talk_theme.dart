import 'package:flutter/material.dart';

@immutable
class AgentTalkVisualTokens extends ThemeExtension<AgentTalkVisualTokens> {
  const AgentTalkVisualTokens({
    required this.ink,
    required this.panel,
    required this.panelRaised,
    required this.structureLine,
    required this.textPrimary,
    required this.textMuted,
    required this.signal,
    required this.attention,
    required this.danger,
  });

  static const dark = AgentTalkVisualTokens(
    ink: Color(0xFF080B10),
    panel: Color(0xFF0E151D),
    panelRaised: Color(0xFF151F2A),
    structureLine: Color(0xFF334454),
    textPrimary: Color(0xFFE8EDF2),
    textMuted: Color(0xFF9AAABA),
    signal: Color(0xFF55D8D0),
    attention: Color(0xFFF0B84B),
    danger: Color(0xFFFF6B6B),
  );

  final Color ink;
  final Color panel;
  final Color panelRaised;
  final Color structureLine;
  final Color textPrimary;
  final Color textMuted;
  final Color signal;
  final Color attention;
  final Color danger;

  @override
  AgentTalkVisualTokens copyWith({
    Color? ink,
    Color? panel,
    Color? panelRaised,
    Color? structureLine,
    Color? textPrimary,
    Color? textMuted,
    Color? signal,
    Color? attention,
    Color? danger,
  }) {
    return AgentTalkVisualTokens(
      ink: ink ?? this.ink,
      panel: panel ?? this.panel,
      panelRaised: panelRaised ?? this.panelRaised,
      structureLine: structureLine ?? this.structureLine,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      signal: signal ?? this.signal,
      attention: attention ?? this.attention,
      danger: danger ?? this.danger,
    );
  }

  @override
  AgentTalkVisualTokens lerp(covariant AgentTalkVisualTokens? other, double t) {
    if (other == null) {
      return this;
    }
    return AgentTalkVisualTokens(
      ink: Color.lerp(ink, other.ink, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panelRaised: Color.lerp(panelRaised, other.panelRaised, t)!,
      structureLine: Color.lerp(structureLine, other.structureLine, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      signal: Color.lerp(signal, other.signal, t)!,
      attention: Color.lerp(attention, other.attention, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

ThemeData buildAgentTalkDarkTheme() {
  const tokens = AgentTalkVisualTokens.dark;
  final colors =
      ColorScheme.fromSeed(
        seedColor: tokens.signal,
        brightness: Brightness.dark,
        surface: tokens.ink,
      ).copyWith(
        primary: tokens.signal,
        onPrimary: tokens.ink,
        primaryContainer: const Color(0xFF123B3C),
        onPrimaryContainer: const Color(0xFFBEFFF9),
        secondary: tokens.attention,
        onSecondary: tokens.ink,
        secondaryContainer: const Color(0xFF4A3712),
        onSecondaryContainer: const Color(0xFFFFE0A3),
        error: tokens.danger,
        onError: tokens.ink,
        surface: tokens.ink,
        onSurface: tokens.textPrimary,
        surfaceContainerLowest: tokens.ink,
        surfaceContainerLow: tokens.panel,
        surfaceContainer: tokens.panel,
        surfaceContainerHigh: tokens.panelRaised,
        surfaceContainerHighest: const Color(0xFF1B2834),
        outline: const Color(0xFF657789),
        outlineVariant: tokens.structureLine,
      );

  const compactShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(4)),
  );
  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: colors,
    extensions: const [tokens],
    scaffoldBackgroundColor: tokens.ink,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.ink,
      foregroundColor: tokens.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerTheme: DividerThemeData(color: tokens.structureLine),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.panel,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        borderSide: BorderSide(color: tokens.structureLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        borderSide: BorderSide(color: tokens.signal, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: compactShape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: compactShape),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: tokens.panel,
      side: BorderSide(color: tokens.structureLine),
      shape: compactShape,
    ),
  );
}

extension AgentTalkThemeContext on BuildContext {
  AgentTalkVisualTokens get visualTokens =>
      Theme.of(this).extension<AgentTalkVisualTokens>()!;
}
