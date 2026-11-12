import 'package:flutter/material.dart';
import 'package:lar_em_dia/core/theme/finance_colors.dart';

abstract final class AppTheme {
  static const fontFamily = 'Inter';

  static const cardRadius = 16.0;

  static const controlRadius = 12.0;

  static const lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF5F6FD6),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFEDEFFC),
    onPrimaryContainer: Color(0xFF2F3A8F),
    secondary: Color(0xFF5C6283),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFDDE1FA),
    onSecondaryContainer: Color(0xFF2F3A8F),
    tertiary: Color(0xFF8A5A00),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFBF0DE),
    onTertiaryContainer: Color(0xFF4D3200),
    error: Color(0xFFC8414A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFCE9EA),
    onErrorContainer: Color(0xFF7A1E24),
    surface: Color(0xFFF4F5FA),
    onSurface: Color(0xFF1B1F33),
    onSurfaceVariant: Color(0xFF6B7089),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF7F8FC),
    surfaceContainerHigh: Color(0xFFEEF0F6),
    surfaceContainerHighest: Color(0xFFE7E9F2),
    outline: Color(0xFFA3A7BC),
    outlineVariant: Color(0xFFE7E9F2),
    inverseSurface: Color(0xFF1B1F33),
    onInverseSurface: Color(0xFFF4F5FA),
    inversePrimary: Color(0xFF8F9CF2),
    shadow: Color(0xFF1B1F33),
    scrim: Color(0xFF000000),
  );

  static const darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF8F9CF2),
    onPrimary: Color(0xFF11163F),
    primaryContainer: Color(0xFF262B45),
    onPrimaryContainer: Color(0xFFDDE1FA),
    secondary: Color(0xFFB4B9D6),
    onSecondary: Color(0xFF1F2440),
    secondaryContainer: Color(0xFF323862),
    onSecondaryContainer: Color(0xFFDDE1FA),
    tertiary: Color(0xFFF0B35A),
    onTertiary: Color(0xFF3B2E17),
    tertiaryContainer: Color(0xFF3B2E17),
    onTertiaryContainer: Color(0xFFFBF0DE),
    error: Color(0xFFF08A8D),
    onError: Color(0xFF3F2125),
    errorContainer: Color(0xFF3F2125),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF11131B),
    onSurface: Color(0xFFE9EAF3),
    onSurfaceVariant: Color(0xFF9DA2BA),
    surfaceContainerLowest: Color(0xFF0C0E14),
    surfaceContainerLow: Color(0xFF1A1D29),
    surfaceContainer: Color(0xFF202435),
    surfaceContainerHigh: Color(0xFF262A3B),
    surfaceContainerHighest: Color(0xFF2A2E40),
    outline: Color(0xFF6B7089),
    outlineVariant: Color(0xFF2A2E40),
    inverseSurface: Color(0xFFE9EAF3),
    onInverseSurface: Color(0xFF1B1F33),
    inversePrimary: Color(0xFF5F6FD6),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static final ThemeData light = _build(lightScheme, FinanceColors.light);

  static final ThemeData dark = _build(darkScheme, FinanceColors.dark);

  static ThemeData _build(ColorScheme scheme, FinanceColors finance) {
    final base = ThemeData(colorScheme: scheme, fontFamily: fontFamily);
    final text = base.textTheme;
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(controlRadius),
    );
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      extensions: [
        finance.copyWith(
          negative: scheme.error,
          negativeContainer: scheme.errorContainer,
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: text.labelLarge?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: text.labelLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: controlShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: controlShape,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
