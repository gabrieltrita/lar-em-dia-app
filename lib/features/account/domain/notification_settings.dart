import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_settings.freezed.dart';

@freezed
abstract class NotificationSettings with _$NotificationSettings {
  const factory({required bool enabled, required int daysBefore}) =
      _NotificationSettings;

  static const minDays = 0;
  static const maxDays = 7;
}
