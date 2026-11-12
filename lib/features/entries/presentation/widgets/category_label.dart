import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

String categoryLabel(AppLocalizations l10n, Category? category) =>
    categoryKeyLabel(l10n, category?.key, fallback: category?.name ?? '');

String categoryKeyLabel(
  AppLocalizations l10n,
  String? key, {
  required String fallback,
}) => switch (key) {
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
  'investment_redemption' => l10n.categoryInvestmentRedemption,
  'reserve_withdrawal' => l10n.categoryReserveWithdrawal,
  'housing' => l10n.categoryHousing,
  'utilities' => l10n.categoryUtilities,
  'internet_phone' => l10n.categoryInternetPhone,
  'subscriptions' => l10n.categorySubscriptions,
  'education' => l10n.categoryEducation,
  'insurance' => l10n.categoryInsurance,
  'health_plan' => l10n.categoryHealthPlan,
  'loans' => l10n.categoryLoans,
  'investment_contribution' => l10n.categoryInvestmentContribution,
  'reserve_deposit' => l10n.categoryReserveDeposit,
  'groceries' => l10n.categoryGroceries,
  'restaurants' => l10n.categoryRestaurants,
  'transport' => l10n.categoryTransport,
  'health' => l10n.categoryHealth,
  'leisure' => l10n.categoryLeisure,
  'travel' => l10n.categoryTravel,
  'clothing' => l10n.categoryClothing,
  'personal_care' => l10n.categoryPersonalCare,
  'pets' => l10n.categoryPets,
  'gifts_donations' => l10n.categoryGiftsDonations,
  'taxes_fees' => l10n.categoryTaxesFees,
  'other_expense' => l10n.categoryOtherExpense,
  _ => fallback,
};
