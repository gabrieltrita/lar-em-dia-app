import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/account/domain/notification_settings.dart';
import 'package:lar_em_dia/features/account/presentation/cubits/account_cubits.dart';
import 'package:lar_em_dia/features/account/presentation/pages/notification_settings_page.dart';
import 'package:lar_em_dia/features/account/presentation/pages/unsubscribe_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/account_fixtures.dart';
import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;
  late MockAccountRepository repository;
  const failure = ApiError(code: ApiError.networkErrorCode);
  const networkMessage = 'Não foi possível conectar. Verifique sua internet.';

  setUpAll(registerAccountFallbacks);
  setUp(() {
    harness = AuthHarness();
    repository = MockAccountRepository();
  });
  tearDown(() => harness.dispose());

  group('NotificationSettingsPage', () {
    Future<void> pump(WidgetTester tester) => pumpPage(
      tester,
      BlocProvider(
        create: (_) => started(
          NotificationSettingsCubit(repository),
          (cubit) => cubit.load(),
        ),
        child: const NotificationSettingsPage(),
      ),
      session: harness.session,
    );

    testWidgets('changes the days and turns the alerts off', (tester) async {
      when(repository.notificationSettings).thenAnswer((_) async => alertsOn);
      when(() => repository.updateNotificationSettings(any())).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments.single as NotificationSettings,
      );
      await pump(tester);

      expect(find.text('1 dia antes'), findsOneWidget);
      await tester.tap(find.byKey(const Key('notifications_days_before')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 dias antes').last);
      await tester.pumpAndSettle();
      verify(
        () => repository.updateNotificationSettings(
          alertsOn.copyWith(daysBefore: 3),
        ),
      ).called(1);

      await tester.tap(find.byKey(const Key('notifications_enabled')));
      await tester.pumpAndSettle();
      verify(
        () => repository.updateNotificationSettings(
          alertsOff.copyWith(daysBefore: 3),
        ),
      ).called(1);
      final dropdown = tester.widget<DropdownButton<int>>(
        find.byType(DropdownButton<int>),
      );
      expect(dropdown.onChanged, isNull);
    });

    testWidgets('lists every day option', (tester) async {
      when(repository.notificationSettings).thenAnswer((_) async => alertsOn);
      await pump(tester);

      await tester.tap(find.byKey(const Key('notifications_days_before')));
      await tester.pumpAndSettle();

      expect(find.text('No dia do vencimento'), findsOneWidget);
      expect(find.text('7 dias antes'), findsOneWidget);
    });

    testWidgets('explains a failed update', (tester) async {
      when(repository.notificationSettings).thenAnswer((_) async => alertsOn);
      when(() => repository.updateNotificationSettings(any()))
          .thenThrow(failure);
      await pump(tester);

      await tester.tap(find.byKey(const Key('notifications_enabled')));
      await tester.pumpAndSettle();

      expect(find.text(networkMessage), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
    });

    testWidgets('retries a failed load', (tester) async {
      when(repository.notificationSettings).thenThrow(failure);
      await pump(tester);
      expect(find.text(networkMessage), findsOneWidget);

      when(repository.notificationSettings).thenAnswer((_) async => alertsOn);
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.byType(SwitchListTile), findsOneWidget);
    });
  });

  group('UnsubscribePage', () {
    Future<void> pump(WidgetTester tester, String? token) => pumpPage(
      tester,
      BlocProvider(
        create: (_) => started(
          UnsubscribeCubit(repository),
          (cubit) => cubit.unsubscribe(token),
        ),
        child: const UnsubscribePage(),
      ),
      session: harness.session,
    );

    testWidgets('confirms and opens the app', (tester) async {
      when(() => repository.unsubscribe('abc'))
          .thenAnswer((_) async => alertsOff);
      await pump(tester, 'abc');

      expect(find.textContaining('não vai mais receber'), findsOneWidget);
      await tester.tap(find.text('Abrir o app'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('explains an invalid link', (tester) async {
      when(() => repository.unsubscribe(''))
          .thenThrow(const ApiError(code: 'invalid_unsubscribe_token'));
      await pump(tester, null);

      expect(find.textContaining('inválido ou expirou'), findsOneWidget);
    });
  });
}
