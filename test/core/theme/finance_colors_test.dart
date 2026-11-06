import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/theme/app_theme.dart';
import 'package:lar_em_dia/core/theme/finance_colors.dart';

void main() {
  group('AppTheme', () {
    test('registers the finance colors with the scheme error as negative', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final finance = theme.extension<FinanceColors>()!;
        expect(finance.negative, theme.colorScheme.error);
        expect(finance.negativeContainer, theme.colorScheme.errorContainer);
      }
      expect(
        AppTheme.light.extension<FinanceColors>()!.positive,
        FinanceColors.light.positive,
      );
      expect(
        AppTheme.dark.extension<FinanceColors>()!.positive,
        FinanceColors.dark.positive,
      );
    });

    test('uses flat cards', () {
      expect(AppTheme.light.cardTheme.elevation, 0);
    });
  });

  group('FinanceColors', () {
    test('colors amounts by sign', () {
      const colors = FinanceColors.light;
      expect(colors.forAmount(1), colors.positive);
      expect(colors.forAmount(-1), colors.negative);
      expect(colors.forAmount(0), isNull);
    });

    test('has a color for every category group in both themes', () {
      for (final colors in [FinanceColors.light, FinanceColors.dark]) {
        expect(colors.categories.keys, unorderedEquals(CategoryGroup.values));
      }
    });

    test('copies with replaced fields', () {
      const color = Color(0xFF123456);
      final copy = FinanceColors.light.copyWith(
        positive: color,
        positiveContainer: color,
        negative: color,
        negativeContainer: color,
        warning: color,
        warningContainer: color,
        categories: {CategoryGroup.other: color},
      );
      expect(copy.positive, color);
      expect(copy.positiveContainer, color);
      expect(copy.negative, color);
      expect(copy.negativeContainer, color);
      expect(copy.warning, color);
      expect(copy.warningContainer, color);
      expect(copy.categories, {CategoryGroup.other: color});
      expect(
        FinanceColors.light.copyWith().positive,
        FinanceColors.light.positive,
      );
    });

    test('interpolates between themes', () {
      const light = FinanceColors.light;
      const dark = FinanceColors.dark;
      expect(light.lerp(null, 0.5), same(light));
      final middle = light.lerp(dark, 1);
      expect(middle.positive, dark.positive);
      expect(middle.positiveContainer, dark.positiveContainer);
      expect(middle.negative, dark.negative);
      expect(middle.negativeContainer, dark.negativeContainer);
      expect(middle.warning, dark.warning);
      expect(middle.warningContainer, dark.warningContainer);
      expect(middle.categories, dark.categories);
    });

    testWidgets('falls back to the light colors with the theme error', (
      tester,
    ) async {
      late FinanceColors colors;
      late ThemeData theme;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              colors = FinanceColors.of(context);
              theme = Theme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(colors.positive, FinanceColors.light.positive);
      expect(colors.negative, theme.colorScheme.error);
      expect(colors.negativeContainer, theme.colorScheme.errorContainer);
    });
  });
}
