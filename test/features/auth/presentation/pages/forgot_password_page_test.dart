import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;

  setUp(() => harness = AuthHarness());
  tearDown(() => harness.dispose());

  Future<void> pump(WidgetTester tester) => pumpPage(
    tester,
    BlocProvider(
      create: (_) => ForgotPasswordCubit(harness.repository),
      child: const ForgotPasswordPage(),
    ),
    session: harness.session,
  );

  Future<void> submitEmail(WidgetTester tester, String email) async {
    await tester.enterText(
      find.byKey(const Key('forgot_password_email')),
      email,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets('validates the email', (tester) async {
    await pump(tester);

    await submitEmail(tester, 'ana');

    expect(find.text('Email inválido'), findsOneWidget);
    verifyZeroInteractions(harness.repository);
  });

  testWidgets('confirms that the link was sent', (tester) async {
    when(() => harness.repository.requestPasswordReset('ana@example.com'))
        .thenAnswer((_) async {});
    await pump(tester);

    await submitEmail(tester, 'ana@example.com');

    expect(
      find.text(
        'Se houver uma conta com esse email, enviamos o link para criar '
        'uma nova senha.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('forgot_password_email')), findsNothing);
  });

  testWidgets('shows the API error', (tester) async {
    when(() => harness.repository.requestPasswordReset('ana@example.com'))
        .thenThrow(const ApiError(code: ApiError.networkErrorCode));
    await pump(tester);

    await submitEmail(tester, 'ana@example.com');

    expect(
      find.text('Não foi possível conectar. Verifique sua internet.'),
      findsOneWidget,
    );
  });

  testWidgets('goes back to the login', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Voltar para o login'));
    await tester.pumpAndSettle();

    expect(find.text(routeMarker(AppRoutes.login)), findsOneWidget);
  });
}
