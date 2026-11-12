abstract interface class ProjectionPreferences {
  Future<bool> includeInvestmentIncome();

  Future<void> setIncludeInvestmentIncome({required bool include});
}
