import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/cache/local_cache.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_cache_reset.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/auth_fixtures.dart';

class MockLocalCache extends Mock implements LocalCache;

void main() {
  late AuthHarness harness;
  late MockLocalCache cache;
  late FinanceCacheReset reset;

  setUp(() {
    harness = AuthHarness();
    cache = MockLocalCache();
    reset = FinanceCacheReset(harness.session, cache);
  });

  tearDown(() async {
    await reset.dispose();
    await harness.dispose();
  });

  test('clears the cache when the signed in user changes', () async {
    reset
      ..start()
      ..start();
    await pumpEventQueue();
    verifyNever(cache.clear);

    harness.session.signedIn(ana);
    await pumpEventQueue();
    harness.session.signedIn(ana.copyWith(firstName: 'Aninha'));
    await pumpEventQueue();
    verify(cache.clear).called(1);

    when(harness.repository.logout).thenAnswer((_) async {});
    await harness.session.logout();
    await pumpEventQueue();
    verify(cache.clear).called(1);
  });

  test('disposes without starting', () async {
    await FinanceCacheReset(harness.session, cache).dispose();
  });
}
