import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/features/projection/domain/projection_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

@LazySingleton(as: ProjectionPreferences)
class PrefsProjectionPreferences implements ProjectionPreferences {
  new(this._preferences);

  static const key = 'projection_include_investment_income';

  final SharedPreferencesAsync _preferences;

  @override
  Future<bool> includeInvestmentIncome() async =>
      await _preferences.getBool(key) ?? true;

  @override
  Future<void> setIncludeInvestmentIncome({required bool include}) =>
      _preferences.setBool(key, include);
}
