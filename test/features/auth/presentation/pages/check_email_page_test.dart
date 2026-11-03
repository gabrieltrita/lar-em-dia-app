import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/check_email_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;

  setUp(() => harness = AuthHarness());
  tearDown(() => harness.dispose());

  Future<void> pump(WidgetTester tester, {String? email}) => pumpPage(
    tester,
    BlocProvider(
      create: (_) => ResendConfirmationCubit(harness.repository),
      child: CheckEmailPage(email: email),
    ),
    session: harness.session,
  );

  testWidgets('resends the link to the prefilled email', (tester) async {
    when(() => harness.repository.resendConfirmation('ana@example.com'))
        .thenAnswer((_) async {});
    await pump(tester, email: 'ana@example.com');

    await tester.tap(find.text('Reenviar link'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Se houver uma conta pendente com esse email, enviamos um novo link.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('requires an email', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Reenviar link'));
    await tester.pump();

    expect(find.text('Campo obrigatório'), findsOneWidget);
    verifyZeroInteractions(harness.repository);
  });

  testWidgets('shows the API error', (tester) async {
    when(() => harness.repository.resendConfirmation('ana@example.com'))
        .thenThrow(const ApiError(code: 'rate_limited'));
    await pump(tester);

    await tester.enterText(
      find.byKey(const Key('check_email_email')),
      'ana@example.com',
    );
    await tester.tap(find.text('Reenviar link'));
    await tester.pumpAndSettle();

    expect(
      find.text('Muitas tentativas. Aguarde um pouco e tente de novo.'),
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
