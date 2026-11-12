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
    required this.heroStart,
    required this.heroEnd,
    required this.categories,
  });

  static const light = FinanceColors(
    positive: Color(0xFF16855B),
    positiveContainer: Color(0xFFE3F5EE),
    negative: Color(0xFFC8414A),
    negativeContainer: Color(0xFFFCE9EA),
    warning: Color(0xFF9A6200),
    warningContainer: Color(0xFFFBF0DE),
    heroStart: Color(0xFF6676DC),
    heroEnd: Color(0xFF8E9CEB),
    categories: {
      CategoryGroup.income: Color(0xFF16855B),
      CategoryGroup.home: Color(0xFF5F6FD6),
      CategoryGroup.food: Color(0xFFD9892A),
      CategoryGroup.transport: Color(0xFF2B9C99),
      CategoryGroup.health: Color(0xFFD2577F),
      CategoryGroup.leisure: Color(0xFF8D6BD1),
      CategoryGroup.personal: Color(0xFFB08A1E),
      CategoryGroup.financial: Color(0xFF5C6B82),
      CategoryGroup.other: Color(0xFF9A9EB3),
    },
  );

  static const dark = FinanceColors(
    positive: Color(0xFF5CCB9C),
    positiveContainer: Color(0xFF173A2E),
    negative: Color(0xFFF08A8D),
    negativeContainer: Color(0xFF3F2125),
    warning: Color(0xFFF0B35A),
    warningContainer: Color(0xFF3B2E17),
    heroStart: Color(0xFF4A57B0),
    heroEnd: Color(0xFF6773C9),
    categories: {
      CategoryGroup.income: Color(0xFF5CCB9C),
      CategoryGroup.home: Color(0xFF8F9CF2),
      CategoryGroup.food: Color(0xFFF0B35A),
      CategoryGroup.transport: Color(0xFF5DC8C4),
      CategoryGroup.health: Color(0xFFEE90B2),
      CategoryGroup.leisure: Color(0xFFB49CEB),
      CategoryGroup.personal: Color(0xFFE6C75A),
      CategoryGroup.financial: Color(0xFFA9B4C8),
      CategoryGroup.other: Color(0xFF8A8FA8),
    },
  );

  final Color positive;
  final Color positiveContainer;
  final Color negative;
  final Color negativeContainer;
  final Color warning;
  final Color warningContainer;
  final Color heroStart;
  final Color heroEnd;
  final Map<CategoryGroup, Color> categories;

  static FinanceColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<FinanceColors>() ??
        light.copyWith(
          negative: theme.colorScheme.error,
          negativeContainer: theme.colorScheme.errorContainer,
        );
  }

  LinearGradient get heroGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [heroStart, heroEnd],
  );

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
    Color? heroStart,
    Color? heroEnd,
    Map<CategoryGroup, Color>? categories,
  }) => FinanceColors(
    positive: positive ?? this.positive,
    positiveContainer: positiveContainer ?? this.positiveContainer,
    negative: negative ?? this.negative,
    negativeContainer: negativeContainer ?? this.negativeContainer,
    warning: warning ?? this.warning,
    warningContainer: warningContainer ?? this.warningContainer,
    heroStart: heroStart ?? this.heroStart,
    heroEnd: heroEnd ?? this.heroEnd,
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
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      categories: {
        for (final group in CategoryGroup.values)
          group: Color.lerp(categories[group], other.categories[group], t)!,
      },
    );
  }
}
