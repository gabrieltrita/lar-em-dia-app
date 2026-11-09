import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/demo/demo_seed.dart';
import 'package:lar_em_dia/features/auth/domain/login_result.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/login_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;

  setUp(() => harness = AuthHarness());
  tearDown(() => harness.dispose());

  final submit = find.widgetWithText(FilledButton, 'Entrar');

  Future<void> pump(WidgetTester tester, {bool demo = false}) => pumpPage(
    tester,
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => LoginCubit(harness.repository)),
        BlocProvider(create: (_) => harness.googleCubit()),
      ],
      child: LoginPage(demo: demo),
    ),
    session: harness.session,
  );

  void stubLogin(Future<LoginResult> Function() answer) => when(
    () => harness.repository.login(
      email: 'ana@example.com',
      password: 'Secret123',
    ),
  ).thenAnswer((_) => answer());

  Future<void> fillIn(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('login_email')),
      ' ana@example.com ',
    );
    await tester.enterText(
      find.byKey(const Key('login_password')),
      'Secret123',
    );
  }

  testWidgets('explains the demo and fills in its account', (tester) async {
    when(
      () => harness.repository.login(
        email: DemoSeed.email,
        password: DemoSeed.password,
      ),
    ).thenAnswer((_) async => const LoginResult.authenticated(ana));
    await pump(tester, demo: true);

    expect(find.textContaining('Modo demonstração'), findsOneWidget);
    expect(find.text(DemoSeed.email), findsOneWidget);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(harness.session.state, const SessionState.authenticated(ana));
  });

  testWidgets('validates the fields before calling the API', (tester) async {
    await pump(tester);
    expect(find.textContaining('Modo demonstração'), findsNothing);

    await tester.tap(submit);
    await tester.pump();

    expect(find.text('Campo obrigatório'), findsNWidgets(2));
    verifyZeroInteractions(harness.repository);
  });

  testWidgets('signs the user in', (tester) async {
    stubLogin(() async => const LoginResult.authenticated(ana));
    await pump(tester);

    await fillIn(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(harness.session.state, const SessionState.authenticated(ana));
  });

  testWidgets('shows progress while the login is running', (tester) async {
    final pending = Completer<LoginResult>();
    stubLogin(() => pending.future);
    await pump(tester);

    await fillIn(tester);
    await tester.tap(submit);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(const LoginResult.authenticated(ana));
    await tester.pumpAndSettle();
  });

  testWidgets('moves to the 2FA step with the challenge', (tester) async {
    stubLogin(() async => const LoginResult.twoFactorRequired('c1'));
    await pump(tester);

    await fillIn(tester);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text(routeMarker(AppRoutes.twoFactor, 'c1')), findsOneWidget);
  });

  testWidgets('shows the API error', (tester) async {
    stubLogin(() async => throw const ApiError(code: 'invalid_credentials'));
    await pump(tester);

    await fillIn(tester);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Email ou senha incorretos.'), findsOneWidget);
    expect(find.text('Reenviar link de confirmação'), findsNothing);
  });

  testWidgets('offers a new confirmation link to unconfirmed accounts', (
    tester,
  ) async {
    stubLogin(() async => throw const ApiError(code: 'email_not_confirmed'));
    await pump(tester);

    await fillIn(tester);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reenviar link de confirmação'));
    await tester.pumpAndSettle();

    expect(
      find.text(routeMarker(AppRoutes.checkEmail, 'ana@example.com')),
      findsOneWidget,
    );
  });

  testWidgets('links to the password recovery', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();

    expect(find.text(routeMarker(AppRoutes.forgotPassword)), findsOneWidget);
  });

  testWidgets('links to the sign up', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();

    expect(find.text(routeMarker(AppRoutes.register)), findsOneWidget);
  });
}
