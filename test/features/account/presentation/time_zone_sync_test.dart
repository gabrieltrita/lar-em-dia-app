import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/account/presentation/time_zone_sync.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/account_fixtures.dart';
import '../../../helpers/auth_fixtures.dart';

void main() {
  late AuthHarness harness;
  late MockAccountRepository repository;
  late MockDeviceTimeZone device;
  late TimeZoneSync sync;

  setUp(() {
    harness = AuthHarness();
    repository = MockAccountRepository();
    device = MockDeviceTimeZone();
    when(device.current).thenAnswer((_) async => 'Europe/Lisbon');
    when(repository.timeZone).thenAnswer((_) async => 'America/Sao_Paulo');
    when(() => repository.updateTimeZone(any())).thenAnswer((_) async {});
    sync = TimeZoneSync(harness.session, repository, device);
  });

  tearDown(() async {
    await sync.dispose();
    await harness.dispose();
  });

  test('sends the device time zone once per signed in user', () async {
    sync.start();
    await pumpEventQueue();
    verifyNever(repository.timeZone);

    harness.session.signedIn(ana);
    await pumpEventQueue();
    harness.session.signedIn(ana.copyWith(firstName: 'Aninha'));
    await pumpEventQueue();
    verify(() => repository.updateTimeZone('Europe/Lisbon')).called(1);

    when(harness.repository.logout).thenAnswer((_) async {});
    await harness.session.logout();
    harness.session.signedIn(ana);
    await pumpEventQueue();
    verify(() => repository.updateTimeZone('Europe/Lisbon')).called(1);
  });

  test('syncs a session that is already signed in when it starts', () async {
    harness.session.signedIn(ana);
    sync
      ..start()
      ..start();
    await pumpEventQueue();

    verify(repository.timeZone).called(1);
  });

  test('leaves a matching time zone alone', () async {
    when(device.current).thenAnswer((_) async => 'America/Sao_Paulo');

    await sync.sync();

    verifyNever(() => repository.updateTimeZone(any()));
  });

  test('ignores API and platform failures', () async {
    when(repository.timeZone)
        .thenThrow(const ApiError(code: ApiError.networkErrorCode));
    await sync.sync();

    when(device.current).thenThrow(PlatformException(code: 'unavailable'));
    await sync.sync();

    verifyNever(() => repository.updateTimeZone(any()));
  });
}
