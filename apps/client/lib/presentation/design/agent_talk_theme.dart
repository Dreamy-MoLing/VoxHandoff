import 'package:flutter/material.dart';

@immutable
class AgentTalkVisualTokens extends ThemeExtension<AgentTalkVisualTokens> {
  const AgentTalkVisualTokens({
    required this.ink,
    required this.panel,
    required this.panelRaised,
    required this.structureLine,
    required this.structureLineStrong,
    required this.textPrimary,
    required this.textMuted,
    required this.signal,
    required this.signalStrong,
    required this.signalDeep,
    required this.signalWarm,
    required this.shadow,
    required this.attention,
    required this.danger,
  });

  static const dark = AgentTalkVisualTokens(
    ink: Color(0xFF05080F),
    panel: Color(0xFF0A1320),
    panelRaised: Color(0xFF101E2E),
    structureLine: Color(0xFF2B4960),
    structureLineStrong: Color(0xFF68869A),
    textPrimary: Color(0xFFEAF7FA),
    textMuted: Color(0xFF91AAB8),
    signal: Color(0xFF63F3E6),
    signalStrong: Color(0xFF63F3E6),
    signalDeep: Color(0xFF0D484B),
    signalWarm: Color(0xFFC9FFFA),
    shadow: Color(0x75000000),
    attention: Color(0xFFFFC866),
    danger: Color(0xFFFF7185),
  );

  static const mobileDark = AgentTalkVisualTokens(
    ink: Color(0xFF070A10),
    panel: Color(0xD10F1622),
    panelRaised: Color(0xFF0D121C),
    structureLine: Color(0x2EADC4E1),
    structureLineStrong: Color(0x57ADC4E1),
    textPrimary: Color(0xFFF2F6FF),
    textMuted: Color(0xFFA8B4C8),
    signal: Color(0xFF9FE7FF),
    signalStrong: Color(0xFF5AC9FF),
    signalDeep: Color(0xFF1779BB),
    signalWarm: Color(0xFFC5B5FF),
    shadow: Color(0x75000000),
    attention: Color(0xFFF4C95D),
    danger: Color(0xFFFF6B7A),
  );

  static const mobileLight = AgentTalkVisualTokens(
    ink: Color(0xFFEDF4FA),
    panel: Color(0xE0F6FBFF),
    panelRaised: Color(0xFFF7FBFF),
    structureLine: Color(0x2B284F70),
    structureLineStrong: Color(0x52284F70),
    textPrimary: Color(0xFF102337),
    textMuted: Color(0xFF50677E),
    signal: Color(0xFF157CA8),
    signalStrong: Color(0xFF0C97C9),
    signalDeep: Color(0xFFA5D9EA),
    signalWarm: Color(0xFF775BD3),
    shadow: Color(0x3D2D5678),
    attention: Color(0xFF9B6A00),
    danger: Color(0xFFB42335),
  );

  final Color ink;
  final Color panel;
  final Color panelRaised;
  final Color structureLine;
  final Color structureLineStrong;
  final Color textPrimary;
  final Color textMuted;
  final Color signal;
  final Color signalStrong;
  final Color signalDeep;
  final Color signalWarm;
  final Color shadow;
  final Color attention;
  final Color danger;

  @override
  AgentTalkVisualTokens copyWith({
    Color? ink,
    Color? panel,
    Color? panelRaised,
    Color? structureLine,
    Color? structureLineStrong,
    Color? textPrimary,
    Color? textMuted,
    Color? signal,
    Color? signalStrong,
    Color? signalDeep,
    Color? signalWarm,
    Color? shadow,
    Color? attention,
    Color? danger,
  }) {
    return AgentTalkVisualTokens(
      ink: ink ?? this.ink,
      panel: panel ?? this.panel,
      panelRaised: panelRaised ?? this.panelRaised,
      structureLine: structureLine ?? this.structureLine,
      structureLineStrong: structureLineStrong ?? this.structureLineStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      signal: signal ?? this.signal,
      signalStrong: signalStrong ?? this.signalStrong,
      signalDeep: signalDeep ?? this.signalDeep,
      signalWarm: signalWarm ?? this.signalWarm,
      shadow: shadow ?? this.shadow,
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
      structureLineStrong: Color.lerp(
        structureLineStrong,
        other.structureLineStrong,
        t,
      )!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      signal: Color.lerp(signal, other.signal, t)!,
      signalStrong: Color.lerp(signalStrong, other.signalStrong, t)!,
      signalDeep: Color.lerp(signalDeep, other.signalDeep, t)!,
      signalWarm: Color.lerp(signalWarm, other.signalWarm, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
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

ThemeData buildAgentTalkMobileDarkTheme() => _buildAgentTalkMobileTheme(
  AgentTalkVisualTokens.mobileDark,
  Brightness.dark,
);

ThemeData buildAgentTalkMobileLightTheme() => _buildAgentTalkMobileTheme(
  AgentTalkVisualTokens.mobileLight,
  Brightness.light,
);

ThemeData _buildAgentTalkMobileTheme(
  AgentTalkVisualTokens tokens,
  Brightness brightness,
) {
  final colors =
      ColorScheme.fromSeed(
        seedColor: tokens.signal,
        brightness: brightness,
        surface: tokens.ink,
      ).copyWith(
        primary: tokens.signal,
        onPrimary: tokens.ink,
        secondary: tokens.signalWarm,
        onSecondary: tokens.ink,
        error: tokens.danger,
        onError: tokens.ink,
        surface: tokens.ink,
        onSurface: tokens.textPrimary,
        surfaceContainerLowest: tokens.ink,
        surfaceContainerLow: tokens.panel,
        surfaceContainer: tokens.panel,
        surfaceContainerHigh: tokens.panelRaised,
        outline: tokens.structureLineStrong,
        outlineVariant: tokens.structureLine,
      );
  const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(18)),
  );
  return ThemeData(
    brightness: brightness,
    colorScheme: colors,
    extensions: [tokens],
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
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: tokens.structureLine),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.panel,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: tokens.structureLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: tokens.signal, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: shape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: shape),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: tokens.panel,
      side: BorderSide(color: tokens.structureLine),
      shape: shape,
    ),
  );
}

extension AgentTalkThemeContext on BuildContext {
  AgentTalkVisualTokens get visualTokens =>
      Theme.of(this).extension<AgentTalkVisualTokens>()!;
}
