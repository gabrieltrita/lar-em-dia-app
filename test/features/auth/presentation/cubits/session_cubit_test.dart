import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/session/session_events.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';

void main() {
  late MockAuthRepository repository;
  late SessionEvents events;

  setUp(() {
    repository = MockAuthRepository();
    events = SessionEvents();
  });

  tearDown(() => events.dispose());

  SessionCubit build() => SessionCubit(repository, events);

  test('starts unknown', () {
    expect(build().state, const SessionState.unknown());
  });

  blocTest<SessionCubit, SessionState>(
    'restores an existing session',
    setUp: () => when(repository.restoreSession).thenAnswer((_) async => ana),
    build: build,
    act: (cubit) => cubit.restore(),
    expect: () => const [SessionState.authenticated(ana)],
  );

  blocTest<SessionCubit, SessionState>(
    'is unauthenticated when nothing can be restored',
    setUp: () => when(repository.restoreSession).thenAnswer((_) async => null),
    build: build,
    act: (cubit) => cubit.restore(),
    expect: () => const [SessionState.unauthenticated()],
  );

  blocTest<SessionCubit, SessionState>(
    'becomes authenticated after a sign in',
    build: build,
    act: (cubit) => cubit.signedIn(ana),
    expect: () => const [SessionState.authenticated(ana)],
  );

  blocTest<SessionCubit, SessionState>(
    'logs out through the repository',
    setUp: () => when(repository.logout).thenAnswer((_) async {}),
    build: build,
    seed: () => const SessionState.authenticated(ana),
    act: (cubit) => cubit.logout(),
    expect: () => const [SessionState.unauthenticated()],
    verify: (_) => verify(repository.logout).called(1),
  );

  blocTest<SessionCubit, SessionState>(
    'ends the session when the refresh expires',
    build: build,
    seed: () => const SessionState.authenticated(ana),
    act: (_) => events.notifyExpired(),
    expect: () => const [SessionState.unauthenticated()],
  );
}
