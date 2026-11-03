import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/reset_password_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;

  setUp(() => harness = AuthHarness());
  tearDown(() => harness.dispose());

  const invalid = 'Este link para criar uma nova senha é inválido ou expirou.';

  Future<void> pump(WidgetTester tester, {String? token = 't1'}) => pumpPage(
    tester,
    BlocProvider(
      create: (_) => ResetPasswordCubit(harness.repository),
      child: ResetPasswordPage(token: token),
    ),
    session: harness.session,
  );

  Future<void> submit(
    WidgetTester tester, {
    String password = 'Secret123',
    String confirmation = 'Secret123',
  }) async {
    await tester.enterText(
      find.byKey(const Key('reset_password_password')),
      password,
    );
    await tester.enterText(
      find.byKey(const Key('reset_password_confirmation')),
      confirmation,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  void stubReset(Future<void> Function() answer) => when(
    () => harness.repository.resetPassword(token: 't1', password: 'Secret123'),
  ).thenAnswer((_) => answer());

  testWidgets('validates the new password', (tester) async {
    await pump(tester);

    await submit(tester, password: 'weak', confirmation: 'other');

    expect(
      find.text('A senha precisa de pelo menos 8 caracteres'),
      findsOneWidget,
    );
    expect(find.text('As senhas não conferem'), findsOneWidget);
    verifyZeroInteractions(harness.repository);
  });

  testWidgets('saves the password and links to the login', (tester) async {
    stubReset(() async {});
    await pump(tester);

    await tester.enterText(
      find.byKey(const Key('reset_password_password')),
      'Secret123',
    );
    await tester.enterText(
      find.byKey(const Key('reset_password_confirmation')),
      'Secret123',
    );
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pumpAndSettle();
    expect(
      find.text('Senha alterada. Entre com a nova senha.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text(routeMarker(AppRoutes.login)), findsOneWidget);
  });

  testWidgets('explains an expired link', (tester) async {
    stubReset(() async => throw const ApiError(code: 'invalid_reset_token'));
    await pump(tester);

    await submit(tester);

    expect(find.text(invalid), findsOneWidget);
  });

  testWidgets('shows the password errors from the API', (tester) async {
    stubReset(
      () async => throw const ApiError(
        code: 'validation_failed',
        details: {
          'password': [FieldError(code: 'too_long')],
        },
      ),
    );
    await pump(tester);

    await submit(tester);

    expect(find.text('Confira os campos destacados.'), findsOneWidget);
    expect(
      find.text('Senha: A senha pode ter no máximo 72 caracteres'),
      findsOneWidget,
    );
  });

  testWidgets('offers a new link when the token is missing', (tester) async {
    await pump(tester, token: null);
    expect(find.text(invalid), findsOneWidget);

    await tester.tap(find.text('Pedir um novo link'));
    await tester.pumpAndSettle();

    expect(find.text(routeMarker(AppRoutes.forgotPassword)), findsOneWidget);
  });
}
