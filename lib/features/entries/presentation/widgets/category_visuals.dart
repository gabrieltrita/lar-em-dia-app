import 'package:flutter/material.dart';
import 'package:lar_em_dia/core/theme/finance_colors.dart';
import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';

typedef CategoryVisual = ({IconData icon, CategoryGroup group});

CategoryVisual categoryVisual(Category? category) =>
    categoryVisualForKey(category?.key, kind: category?.kind);

CategoryVisual categoryVisualForKey(
  String? key, {
  EntryKind? kind,
}) => switch (key) {
  'salary' => (icon: Icons.work_outline, group: CategoryGroup.income),
  'thirteenth_salary' => (
    icon: Icons.event_available_outlined,
    group: CategoryGroup.income,
  ),
  'vacation_bonus' => (
    icon: Icons.beach_access_outlined,
    group: CategoryGroup.income,
  ),
  'bonus' => (icon: Icons.emoji_events_outlined, group: CategoryGroup.income),
  'extra_income' => (icon: Icons.trending_up, group: CategoryGroup.income),
  'rent_received' => (
    icon: Icons.apartment_outlined,
    group: CategoryGroup.income,
  ),
  'alimony_received' => (
    icon: Icons.family_restroom_outlined,
    group: CategoryGroup.income,
  ),
  'tax_refund' => (
    icon: Icons.receipt_long_outlined,
    group: CategoryGroup.income,
  ),
  'reimbursement' => (icon: Icons.replay, group: CategoryGroup.income),
  'other_income' => (icon: Icons.savings_outlined, group: CategoryGroup.income),
  'housing' => (icon: Icons.home_outlined, group: CategoryGroup.home),
  'utilities' => (icon: Icons.lightbulb_outline, group: CategoryGroup.home),
  'internet_phone' => (icon: Icons.wifi, group: CategoryGroup.home),
  'groceries' => (
    icon: Icons.shopping_cart_outlined,
    group: CategoryGroup.food,
  ),
  'restaurants' => (icon: Icons.restaurant_outlined, group: CategoryGroup.food),
  'transport' => (
    icon: Icons.directions_car_outlined,
    group: CategoryGroup.transport,
  ),
  'health_plan' => (
    icon: Icons.health_and_safety_outlined,
    group: CategoryGroup.health,
  ),
  'health' => (
    icon: Icons.medical_services_outlined,
    group: CategoryGroup.health,
  ),
  'subscriptions' => (
    icon: Icons.subscriptions_outlined,
    group: CategoryGroup.leisure,
  ),
  'leisure' => (
    icon: Icons.sports_esports_outlined,
    group: CategoryGroup.leisure,
  ),
  'travel' => (icon: Icons.flight_takeoff, group: CategoryGroup.leisure),
  'education' => (icon: Icons.school_outlined, group: CategoryGroup.personal),
  'clothing' => (icon: Icons.checkroom, group: CategoryGroup.personal),
  'personal_care' => (icon: Icons.spa_outlined, group: CategoryGroup.personal),
  'pets' => (icon: Icons.pets, group: CategoryGroup.personal),
  'gifts_donations' => (
    icon: Icons.volunteer_activism_outlined,
    group: CategoryGroup.personal,
  ),
  'insurance' => (icon: Icons.shield_outlined, group: CategoryGroup.financial),
  'loans' => (
    icon: Icons.account_balance_outlined,
    group: CategoryGroup.financial,
  ),
  'taxes_fees' => (
    icon: Icons.request_quote_outlined,
    group: CategoryGroup.financial,
  ),
  'investment_contribution' => (
    icon: Icons.candlestick_chart_outlined,
    group: CategoryGroup.financial,
  ),
  'investment_redemption' => (
    icon: Icons.currency_exchange,
    group: CategoryGroup.income,
  ),
  'other_expense' => (icon: Icons.more_horiz, group: CategoryGroup.other),
  _ => (
    icon: Icons.label_outline,
    group: kind == EntryKind.income
        ? CategoryGroup.income
        : CategoryGroup.other,
  ),
};

class CategoryAvatar extends StatelessWidget {
  new({required Category? category, super.key})
    : visual = categoryVisual(category);

  new forKey(String categoryKey, {super.key})
    : visual = categoryVisualForKey(categoryKey, kind: EntryKind.expense);

  final CategoryVisual visual;

  @override
  Widget build(BuildContext context) {
    final color = FinanceColors.of(context).categories[visual.group]!;
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: 20,
        backgroundColor: color.withValues(alpha: 0.16),
        child: Icon(visual.icon, color: color, size: 22),
      ),
    );
  }
}
