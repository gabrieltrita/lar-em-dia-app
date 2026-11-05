import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/account/domain/notification_settings.dart';
import 'package:lar_em_dia/features/account/presentation/cubits/account_cubits.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/account_fixtures.dart';

void main() {
  late MockAccountRepository repository;
  const failure = ApiError(code: ApiError.networkErrorCode);
  const loading = LoadState<NotificationSettings>.loading();

  setUpAll(registerAccountFallbacks);
  setUp(() => repository = MockAccountRepository());

  group('NotificationSettingsCubit', () {
    blocTest<NotificationSettingsCubit, LoadState<NotificationSettings>>(
      'loads, updates and keeps the settings when an update fails',
      build: () => NotificationSettingsCubit(repository),
      setUp: () {
        when(repository.notificationSettings).thenAnswer((_) async => alertsOn);
        when(() => repository.updateNotificationSettings(alertsOff))
            .thenAnswer((_) async => alertsOff);
        when(() => repository.updateNotificationSettings(alertsOn))
            .thenThrow(failure);
      },
      act: (cubit) async {
        await cubit.load();
        expect(await cubit.update(alertsOff), isNull);
        expect(await cubit.update(alertsOn), failure);
      },
      expect: () => [
        loading,
        const LoadState.loaded(alertsOn),
        const LoadState.loaded(alertsOff),
      ],
    );

    blocTest<NotificationSettingsCubit, LoadState<NotificationSettings>>(
      'reports a failed load',
      build: () => NotificationSettingsCubit(repository),
      setUp: () => when(repository.notificationSettings).thenThrow(failure),
      act: (cubit) => cubit.load(),
      expect: () => [
        loading,
        const LoadState<NotificationSettings>.failure(failure),
      ],
    );
  });

  group('UnsubscribeCubit', () {
    blocTest<UnsubscribeCubit, LoadState<NotificationSettings>>(
      'turns the alerts off with the token',
      build: () => UnsubscribeCubit(repository),
      setUp: () =>
          when(() => repository.unsubscribe('abc'))
              .thenAnswer((_) async => alertsOff),
      act: (cubit) => cubit.unsubscribe('abc'),
      expect: () => [loading, const LoadState.loaded(alertsOff)],
    );

    blocTest<UnsubscribeCubit, LoadState<NotificationSettings>>(
      'reports an invalid or missing token',
      build: () => UnsubscribeCubit(repository),
      setUp: () =>
          when(() => repository.unsubscribe(''))
              .thenThrow(const ApiError(code: 'invalid_unsubscribe_token')),
      act: (cubit) => cubit.unsubscribe(null),
      expect: () => [
        loading,
        const LoadState<NotificationSettings>.failure(
          ApiError(code: 'invalid_unsubscribe_token'),
        ),
      ],
    );
  });
}
