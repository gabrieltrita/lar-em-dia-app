import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/features/admin/domain/admin_metrics.dart';

part 'admin_metrics_dto.freezed.dart';
part 'admin_metrics_dto.g.dart';

@freezed
abstract class UserMetricsDto with _$UserMetricsDto {
  const factory({
    @Default(0) int total,
    @Default(0) int confirmed,
    @JsonKey(name: 'active_30d') @Default(0) int active30d,
    @JsonKey(name: 'new_30d') @Default(0) int new30d,
    @Default(0) int deactivated,
    @Default(0) int withTwoFactor,
  }) = _UserMetricsDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) => _$UserMetricsDtoFromJson(json);

  UserMetrics toDomain() => UserMetrics(
    total: total,
    confirmed: confirmed,
    active30d: active30d,
    new30d: new30d,
    deactivated: deactivated,
    withTwoFactor: withTwoFactor,
  );
}

@freezed
abstract class EngagementMetricsDto with _$EngagementMetricsDto {
  const factory({
    @Default(0) int withBalance,
    @Default(0) int withEntries,
    @JsonKey(name: 'with_5_series') @Default(0) int withFiveSeries,
    @JsonKey(name: 'entries_created_30d') @Default(0) int entriesCreated30d,
  }) = _EngagementMetricsDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$EngagementMetricsDtoFromJson(json);

  EngagementMetrics toDomain() => EngagementMetrics(
    withBalance: withBalance,
    withEntries: withEntries,
    withFiveSeries: withFiveSeries,
    entriesCreated30d: entriesCreated30d,
  );
}

@freezed
abstract class WeeklySignupsDto with _$WeeklySignupsDto {
  const factory({required String week, required int count}) = _WeeklySignupsDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$WeeklySignupsDtoFromJson(json);

  WeeklySignups toDomain() =>
      WeeklySignups(week: Dates.parseIso(week), count: count);
}

@freezed
abstract class AdminMetricsDto with _$AdminMetricsDto {
  const factory({
    required UserMetricsDto users,
    required EngagementMetricsDto engagement,
    @Default(<WeeklySignupsDto>[]) List<WeeklySignupsDto> signupsByWeek,
  }) = _AdminMetricsDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$AdminMetricsDtoFromJson(json);

  AdminMetrics toDomain() => AdminMetrics(
    users: users.toDomain(),
    engagement: engagement.toDomain(),
    signupsByWeek: [for (final week in signupsByWeek) week.toDomain()],
  );
}
