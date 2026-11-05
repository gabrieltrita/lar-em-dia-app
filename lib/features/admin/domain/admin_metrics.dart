import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_metrics.freezed.dart';

@freezed
abstract class UserMetrics with _$UserMetrics {
  const factory({
    required int total,
    required int confirmed,
    required int active30d,
    required int new30d,
    required int deactivated,
    required int withTwoFactor,
  }) = _UserMetrics;
}

@freezed
abstract class EngagementMetrics with _$EngagementMetrics {
  const factory({
    required int withBalance,
    required int withEntries,
    required int withFiveSeries,
    required int entriesCreated30d,
  }) = _EngagementMetrics;
}

@freezed
abstract class WeeklySignups with _$WeeklySignups {
  const factory({required DateTime week, required int count}) = _WeeklySignups;
}

@freezed
abstract class AdminMetrics with _$AdminMetrics {
  const factory({
    required UserMetrics users,
    required EngagementMetrics engagement,
    required List<WeeklySignups> signupsByWeek,
  }) = _AdminMetrics;
}
