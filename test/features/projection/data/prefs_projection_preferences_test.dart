import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/features/projection/data/prefs_projection_preferences.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPreferences extends Mock implements SharedPreferencesAsync;

void main() {
  late MockPreferences preferences;
  late PrefsProjectionPreferences projection;

  setUp(() {
    preferences = MockPreferences();
    projection = PrefsProjectionPreferences(preferences);
  });

  test('includes the forecast income until switched off', () async {
    when(() => preferences.getBool(PrefsProjectionPreferences.key))
        .thenAnswer((_) async => null);
    expect(await projection.includeInvestmentIncome(), isTrue);

    when(() => preferences.getBool(PrefsProjectionPreferences.key))
        .thenAnswer((_) async => false);
    expect(await projection.includeInvestmentIncome(), isFalse);
  });

  test('stores the choice', () async {
    when(() => preferences.setBool(any(), any())).thenAnswer((_) async {});

    await projection.setIncludeInvestmentIncome(include: false);

    verify(() => preferences.setBool(PrefsProjectionPreferences.key, false))
        .called(1);
  });
}
