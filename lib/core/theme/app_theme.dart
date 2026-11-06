import 'package:flutter/material.dart';
import 'package:lar_em_dia/core/theme/finance_colors.dart';

abstract final class AppTheme {
  static const _seed = Color(0xFF2E7D5B);

  static final ThemeData light = _build(Brightness.light, FinanceColors.light);

  static final ThemeData dark = _build(Brightness.dark, FinanceColors.dark);

  static ThemeData _build(Brightness brightness, FinanceColors finance) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      extensions: [
        finance.copyWith(
          negative: scheme.error,
          negativeContainer: scheme.errorContainer,
        ),
      ],
      cardTheme: CardThemeData(elevation: 0, color: scheme.surfaceContainerLow),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
