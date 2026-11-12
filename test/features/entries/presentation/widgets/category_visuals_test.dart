import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/theme/app_theme.dart';
import 'package:lar_em_dia/core/theme/finance_colors.dart';
import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_visuals.dart';

import '../../../../helpers/finance_fixtures.dart';

const incomeKeys = [
  'salary',
  'thirteenth_salary',
  'vacation_bonus',
  'bonus',
  'extra_income',
  'rent_received',
  'alimony_received',
  'tax_refund',
  'reimbursement',
  'other_income',
  'investment_redemption',
];

const expenseKeys = [
  'housing',
  'utilities',
  'internet_phone',
  'subscriptions',
  'education',
  'insurance',
  'health_plan',
  'loans',
  'groceries',
  'restaurants',
  'transport',
  'health',
  'leisure',
  'travel',
  'clothing',
  'personal_care',
  'pets',
  'gifts_donations',
  'taxes_fees',
  'other_expense',
  'investment_contribution',
];

Category categoryWith(String key, EntryKind kind) =>
    Category(id: key, kind: kind, key: key, name: key);

void main() {
  test('gives every default category its own icon', () {
    final icons = {
      for (final key in incomeKeys)
        categoryVisual(categoryWith(key, EntryKind.income)).icon,
      for (final key in expenseKeys)
        categoryVisual(categoryWith(key, EntryKind.expense)).icon,
    };
    expect(icons, hasLength(incomeKeys.length + expenseKeys.length));
    expect(icons, isNot(contains(Icons.label_outline)));
  });

  test('puts income in the income group and expenses elsewhere', () {
    for (final key in incomeKeys) {
      expect(
        categoryVisual(categoryWith(key, EntryKind.income)).group,
        CategoryGroup.income,
      );
    }
    for (final key in expenseKeys) {
      expect(
        categoryVisual(categoryWith(key, EntryKind.expense)).group,
        isNot(CategoryGroup.income),
      );
    }
  });

  test('falls back to a generic icon grouped by kind', () {
    expect(categoryVisual(categoryWith('new_income', EntryKind.income)), (
      icon: Icons.label_outline,
      group: CategoryGroup.income,
    ));
    expect(categoryVisual(categoryWith('new_expense', EntryKind.expense)), (
      icon: Icons.label_outline,
      group: CategoryGroup.other,
    ));
    expect(categoryVisual(null), (
      icon: Icons.label_outline,
      group: CategoryGroup.other,
    ));
  });

  testWidgets('CategoryAvatar paints the icon in the group color', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              CategoryAvatar(category: housingCategory),
              CategoryAvatar.forKey('travel'),
              CategoryAvatar.forKey('created_by_admin'),
            ],
          ),
        ),
      ),
    );

    final colors = FinanceColors.light.categories;
    final icon = tester.widget<Icon>(find.byIcon(Icons.home_outlined));
    expect(icon.color, colors[CategoryGroup.home]);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.label_outline)).color,
      colors[CategoryGroup.other],
    );
    expect(categoryVisualForKey('housing'), categoryVisual(housingCategory));
  });
}
