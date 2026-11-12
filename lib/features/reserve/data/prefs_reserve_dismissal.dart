import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve_dismissal.dart';
import 'package:shared_preferences/shared_preferences.dart';

@LazySingleton(as: ReserveDismissal)
class PrefsReserveDismissal implements ReserveDismissal {
  new(this._preferences);

  static const key = 'reserve_card_dismissed_until';

  final SharedPreferencesAsync _preferences;

  @override
  Future<DateTime?> dismissedUntil() async {
    final value = await _preferences.getString(key);
    return value == null ? null : DateTime.tryParse(value);
  }

  @override
  Future<void> dismiss(DateTime now) => _preferences.setString(
    key,
    now.add(ReserveDismissal.period).toIso8601String(),
  );
}
