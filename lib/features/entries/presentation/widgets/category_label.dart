import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

String categoryLabel(AppLocalizations l10n, Category? category) =>
    switch (category?.key) {
      'salary' => l10n.categorySalary,
      'thirteenth_salary' => l10n.categoryThirteenthSalary,
      'vacation_bonus' => l10n.categoryVacationBonus,
      'bonus' => l10n.categoryBonus,
      'extra_income' => l10n.categoryExtraIncome,
      'rent_received' => l10n.categoryRentReceived,
      'alimony_received' => l10n.categoryAlimonyReceived,
      'tax_refund' => l10n.categoryTaxRefund,
      'reimbursement' => l10n.categoryReimbursement,
      'other_income' => l10n.categoryOtherIncome,
      _ => category?.name ?? '',
    };
