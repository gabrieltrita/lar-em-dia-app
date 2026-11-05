import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/two_factor_page.dart';
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
      create: (_) => TwoFactorCubit(harness.repository),
      child: const TwoFactorPage(challengeToken: 'c1'),
    ),
    session: harness.session,
  );

  Future<void> submitCode(WidgetTester tester, String code) async {
    await tester.enterText(find.byKey(const Key('two_factor_code')), code);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets('requires a code', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Verificar'));
    await tester.pump();

    expect(find.text('Campo obrigatório'), findsOneWidget);
    verifyZeroInteractions(harness.repository);
  });

  testWidgets('finishes the login with the code', (tester) async {
    when(
      () => harness.repository.verifyTwoFactor(
        challengeToken: 'c1',
        code: '123456',
      ),
    ).thenAnswer((_) async => ana);
    await pump(tester);

    await submitCode(tester, ' 123456 ');

    expect(harness.session.state, const SessionState.authenticated(ana));
  });

  testWidgets('shows a wrong code', (tester) async {
    when(
      () => harness.repository.verifyTwoFactor(
        challengeToken: 'c1',
        code: '000000',
      ),
    ).thenThrow(const ApiError(code: 'invalid_two_factor_code'));
    await pump(tester);

    await submitCode(tester, '000000');

    expect(find.text('Código incorreto.'), findsOneWidget);
  });

  testWidgets('goes back to the login', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Voltar para o login'));
    await tester.pumpAndSettle();

    expect(find.text(routeMarker(AppRoutes.login)), findsOneWidget);
  });
}
