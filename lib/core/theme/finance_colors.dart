import 'package:flutter/material.dart';

enum CategoryGroup {
  income,
  home,
  food,
  transport,
  health,
  leisure,
  personal,
  financial,
  other,
}

@immutable
class FinanceColors extends ThemeExtension<FinanceColors> {
  const new({
    required this.positive,
    required this.positiveContainer,
    required this.negative,
    required this.negativeContainer,
    required this.warning,
    required this.warningContainer,
    required this.categories,
  });

  static const light = FinanceColors(
    positive: Color(0xFF1B7F4C),
    positiveContainer: Color(0xFFD5F2E0),
    negative: Color(0xFFBA1A1A),
    negativeContainer: Color(0xFFFFDAD6),
    warning: Color(0xFF8A5A00),
    warningContainer: Color(0xFFFFDDB0),
    categories: {
      CategoryGroup.income: Color(0xFF1B7F4C),
      CategoryGroup.home: Color(0xFF3B6EA8),
      CategoryGroup.food: Color(0xFFB45F14),
      CategoryGroup.transport: Color(0xFF00796B),
      CategoryGroup.health: Color(0xFFC2185B),
      CategoryGroup.leisure: Color(0xFF7B4FB0),
      CategoryGroup.personal: Color(0xFF8D6E00),
      CategoryGroup.financial: Color(0xFF455A64),
      CategoryGroup.other: Color(0xFF6D6D6D),
    },
  );

  static const dark = FinanceColors(
    positive: Color(0xFF7AD9A0),
    positiveContainer: Color(0xFF0E5233),
    negative: Color(0xFFFFB4AB),
    negativeContainer: Color(0xFF93000A),
    warning: Color(0xFFF4BE5C),
    warningContainer: Color(0xFF684300),
    categories: {
      CategoryGroup.income: Color(0xFF7AD9A0),
      CategoryGroup.home: Color(0xFF9EC4F0),
      CategoryGroup.food: Color(0xFFFFB77A),
      CategoryGroup.transport: Color(0xFF6FD8C8),
      CategoryGroup.health: Color(0xFFFF9EC0),
      CategoryGroup.leisure: Color(0xFFCDB0F5),
      CategoryGroup.personal: Color(0xFFE6C75A),
      CategoryGroup.financial: Color(0xFFB0C4CE),
      CategoryGroup.other: Color(0xFFC4C4C4),
    },
  );

  final Color positive;
  final Color positiveContainer;
  final Color negative;
  final Color negativeContainer;
  final Color warning;
  final Color warningContainer;
  final Map<CategoryGroup, Color> categories;

  static FinanceColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<FinanceColors>() ??
        light.copyWith(
          negative: theme.colorScheme.error,
          negativeContainer: theme.colorScheme.errorContainer,
        );
  }

  Color? forAmount(int cents) => switch (cents) {
    > 0 => positive,
    < 0 => negative,
    _ => null,
  };

  @override
  FinanceColors copyWith({
    Color? positive,
    Color? positiveContainer,
    Color? negative,
    Color? negativeContainer,
    Color? warning,
    Color? warningContainer,
    Map<CategoryGroup, Color>? categories,
  }) => FinanceColors(
    positive: positive ?? this.positive,
    positiveContainer: positiveContainer ?? this.positiveContainer,
    negative: negative ?? this.negative,
    negativeContainer: negativeContainer ?? this.negativeContainer,
    warning: warning ?? this.warning,
    warningContainer: warningContainer ?? this.warningContainer,
    categories: categories ?? this.categories,
  );

  @override
  FinanceColors lerp(FinanceColors? other, double t) {
    if (other == null) {
      return this;
    }
    return FinanceColors(
      positive: Color.lerp(positive, other.positive, t)!,
      positiveContainer: Color.lerp(
        positiveContainer,
        other.positiveContainer,
        t,
      )!,
      negative: Color.lerp(negative, other.negative, t)!,
      negativeContainer: Color.lerp(
        negativeContainer,
        other.negativeContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      categories: {
        for (final group in CategoryGroup.values)
          group: Color.lerp(categories[group], other.categories[group], t)!,
      },
    );
  }
}
