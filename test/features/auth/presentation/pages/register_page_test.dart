import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/register_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/fake_url_launcher.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;

  setUpAll(registerAuthFallbacks);
  setUp(() => harness = AuthHarness());
  tearDown(() => harness.dispose());

  final submit = find.widgetWithText(FilledButton, 'Criar conta');

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpPage(
      tester,
      BlocProvider(
        create: (_) => RegisterCubit(harness.repository),
        child: const RegisterPage(),
      ),
      session: harness.session,
    );
  }

  Future<void> fillIn(
    WidgetTester tester, {
    String lastName = 'Souza',
    String confirmation = 'Secret123',
  }) async {
    await tester.enterText(
      find.byKey(const Key('register_first_name')),
      ' Ana ',
    );
    await tester.enterText(
      find.byKey(const Key('register_last_name')),
      lastName,
    );
    await tester.enterText(
      find.byKey(const Key('register_email')),
      'ana@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register_password')),
      'Secret123',
    );
    await tester.enterText(
      find.byKey(const Key('register_password_confirmation')),
      confirmation,
    );
    await tester.tap(find.byKey(const Key('register_accept_terms')));
    await tester.tap(find.byKey(const Key('register_accept_privacy')));
    await tester.pump();
  }

  testWidgets('validates the form and the consents', (tester) async {
    await pump(tester);

    await tester.tap(submit);
    await tester.pump();

    expect(find.text('Campo obrigatório'), findsNWidgets(5));
    verifyZeroInteractions(harness.repository);
  });

  testWidgets('rejects a different confirmation', (tester) async {
    await pump(tester);

    await fillIn(tester, confirmation: 'Other1234');
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('As senhas não conferem'), findsOneWidget);
  });

  testWidgets('signs up and asks to check the email', (tester) async {
    when(() => harness.repository.register(anaRegistration))
        .thenAnswer((_) async {});
    await pump(tester);

    await fillIn(tester);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(
      find.text(routeMarker(AppRoutes.checkEmail, 'ana@example.com')),
      findsOneWidget,
    );
  });

  testWidgets('sends no last name when it is blank', (tester) async {
    when(() => harness.repository.register(any())).thenAnswer((_) async {});
    await pump(tester);

    await fillIn(tester, lastName: '  ');
    await tester.tap(submit);
    await tester.pumpAndSettle();

    verify(
      () =>
          harness.repository.register(anaRegistration.copyWith(lastName: null)),
    ).called(1);
  });

  testWidgets('lists the field errors from the API', (tester) async {
    when(() => harness.repository.register(any())).thenThrow(
      const ApiError(
        code: 'validation_failed',
        details: {
          'password': [FieldError(code: 'weak_password')],
        },
      ),
    );
    await pump(tester);

    await fillIn(tester);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Confira os campos destacados.'), findsOneWidget);
    expect(
      find.text('Senha: Use letras maiúsculas, minúsculas e números'),
      findsOneWidget,
    );
  });

  testWidgets('opens the terms and the privacy policy', (tester) async {
    final launcher = FakeUrlLauncher.install();
    await pump(tester);

    await tester.tap(find.byTooltip('Ler os termos de uso'));
    await tester.tap(find.byTooltip('Ler a política de privacidade'));

    expect(launcher.launched.map((launch) => Uri.parse(launch.$1).path), [
      '/terms.html',
      '/privacy.html',
    ]);
  });

  testWidgets('links back to the login', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Já tenho conta'));
    await tester.pumpAndSettle();

    expect(find.text(routeMarker(AppRoutes.login)), findsOneWidget);
  });
}
