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
    ink: Color(0xFF05080F),
    panel: Color(0xFF0A1320),
    panelRaised: Color(0xFF101E2E),
    structureLine: Color(0xFF2B4960),
    textPrimary: Color(0xFFEAF7FA),
    textMuted: Color(0xFF91AAB8),
    signal: Color(0xFF63F3E6),
    attention: Color(0xFFFFC866),
    danger: Color(0xFFFF7185),
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
        primaryContainer: const Color(0xFF0D484B),
        onPrimaryContainer: const Color(0xFFC9FFFA),
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
        surfaceContainerHighest: const Color(0xFF172C40),
        outline: const Color(0xFF68869A),
        outlineVariant: tokens.structureLine,
      );

  const compactShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
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
    cardTheme: CardThemeData(
      color: tokens.panelRaised,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        side: BorderSide(color: tokens.structureLine.withValues(alpha: 0.7)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.panel,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: tokens.structureLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
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
