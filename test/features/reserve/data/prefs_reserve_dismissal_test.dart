import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/features/reserve/data/prefs_reserve_dismissal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPreferences extends Mock implements SharedPreferencesAsync;

void main() {
  late MockPreferences preferences;
  late PrefsReserveDismissal dismissal;

  setUp(() {
    preferences = MockPreferences();
    dismissal = PrefsReserveDismissal(preferences);
  });

  test('has no dismissal before the first one', () async {
    when(() => preferences.getString(PrefsReserveDismissal.key))
        .thenAnswer((_) async => null);

    expect(await dismissal.dismissedUntil(), isNull);
  });

  test('stores a dismissal for 30 days', () async {
    when(() => preferences.setString(any(), any())).thenAnswer((_) async {});

    await dismissal.dismiss(DateTime(2026, 11, 12, 9));

    verify(
      () => preferences.setString(
        PrefsReserveDismissal.key,
        '2026-12-12T09:00:00.000',
      ),
    ).called(1);
  });

  test('reads the stored date and ignores a broken value', () async {
    when(() => preferences.getString(PrefsReserveDismissal.key))
        .thenAnswer((_) async => '2026-12-12T09:00:00.000');
    expect(await dismissal.dismissedUntil(), DateTime(2026, 12, 12, 9));

    when(() => preferences.getString(PrefsReserveDismissal.key))
        .thenAnswer((_) async => 'broken');
    expect(await dismissal.dismissedUntil(), isNull);
  });
}
