import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/auth/domain/login_result.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/auth/presentation/widgets/google_sign_in_section.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/fake_url_launcher.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;

  setUp(() => harness = AuthHarness());
  tearDown(() => harness.dispose());

  final button = find.byKey(const Key('google_sign_in'));

  const consentsMissing = ApiError(
    code: 'validation_failed',
    details: {
      'accept_terms': [FieldError(code: 'required')],
    },
  );

  Future<void> pump(WidgetTester tester, {FakeGoogleAuth? google}) => pumpPage(
    tester,
    BlocProvider(
      create: (_) =>
          GoogleSignInCubit(harness.repository, google ?? harness.google),
      child: const Scaffold(body: GoogleSignInSection()),
    ),
    session: harness.session,
  );

  Future<void> signInWithGoogle(WidgetTester tester) async {
    await tester.tap(button);
    await tester.pump();
    harness.google.emit('google-token');
    await tester.pumpAndSettle();
  }

  testWidgets('stays hidden without a Google client id', (tester) async {
    final google = FakeGoogleAuth(enabled: false);
    addTearDown(google.dispose);
    await pump(tester, google: google);

    expect(find.text('ou'), findsNothing);
    expect(button, findsNothing);
  });

  testWidgets('shows Google own button where it renders one', (tester) async {
    final google = FakeGoogleAuth(rendersOwnButton: true);
    addTearDown(google.dispose);
    await pump(tester, google: google);

    expect(find.text('ou'), findsOneWidget);
    expect(button, findsNothing);
  });

  testWidgets('signs in with the token from Google', (tester) async {
    when(() => harness.repository.signInWithGoogle('google-token'))
        .thenAnswer((_) async => const LoginResult.authenticated(ana));
    await pump(tester);

    expect(find.text('Continuar com o Google'), findsOneWidget);
    await signInWithGoogle(tester);

    expect(harness.google.signIns, 1);
    expect(harness.session.state, const SessionState.authenticated(ana));
  });

  testWidgets('moves to the 2FA step with the challenge', (tester) async {
    when(() => harness.repository.signInWithGoogle('google-token'))
        .thenAnswer((_) async => const LoginResult.twoFactorRequired('c1'));
    await pump(tester);

    await signInWithGoogle(tester);

    expect(find.text(routeMarker(AppRoutes.twoFactor, 'c1')), findsOneWidget);
  });

  testWidgets('asks for the consents before creating the account', (
    tester,
  ) async {
    final launcher = FakeUrlLauncher.install();
    when(() => harness.repository.signInWithGoogle('google-token'))
        .thenThrow(consentsMissing);
    when(
      () => harness.repository.signInWithGoogle(
        'google-token',
        acceptConsents: true,
      ),
    ).thenAnswer((_) async => const LoginResult.authenticated(ana));
    await pump(tester);

    await signInWithGoogle(tester);

    expect(find.text('Criar conta com o Google'), findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);
    await tester.tap(find.text('Ler os termos de uso'));
    await tester.tap(find.text('Ler a política de privacidade'));
    expect(launcher.launched, hasLength(2));
    await tester.tap(find.text('Aceitar e criar conta'));
    await tester.pumpAndSettle();

    expect(harness.session.state, const SessionState.authenticated(ana));
  });

  testWidgets('creates nothing when the consents are declined', (tester) async {
    when(() => harness.repository.signInWithGoogle('google-token'))
        .thenThrow(consentsMissing);
    await pump(tester);

    await signInWithGoogle(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    verifyNever(
      () => harness.repository.signInWithGoogle(
        'google-token',
        acceptConsents: true,
      ),
    );
    expect(find.text('Criar conta com o Google'), findsNothing);
    expect(find.text('Campo obrigatório'), findsNothing);
  });

  testWidgets('shows progress and then the error', (tester) async {
    when(() => harness.repository.signInWithGoogle('google-token')).thenAnswer(
      (_) => Future.delayed(
        const Duration(seconds: 1),
        () => throw const ApiError(code: 'oauth_email_unverified'),
      ),
    );
    await pump(tester);

    await tester.tap(button);
    harness.google.emit('google-token');
    await tester.pump();
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(
      find.text('Confirme o seu email no Google antes de entrar.'),
      findsOneWidget,
    );
  });
}
