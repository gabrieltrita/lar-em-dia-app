import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/auth/domain/login_result.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/unlock_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;

  setUp(() => harness = AuthHarness());
  tearDown(() => harness.dispose());

  Future<void> pump(WidgetTester tester, {String? token, bool settle = true}) =>
      pumpPage(
        tester,
        BlocProvider(
          create: (_) => UnlockCubit(harness.repository),
          child: UnlockPage(token: token),
        ),
        session: harness.session,
        settle: settle,
      );

  const invalid =
      'Este link de desbloqueio é inválido, já foi usado ou a conta não está '
      'mais bloqueada.';

  testWidgets('unlocks the account and signs the user in', (tester) async {
    when(() => harness.repository.unlock('t1'))
        .thenAnswer((_) async => const LoginResult.authenticated(ana));

    await pump(tester, token: 't1', settle: false);
    await tester.pump();

    expect(harness.session.state, const SessionState.authenticated(ana));
  });

  testWidgets('asks for the 2FA code when the account has 2FA', (tester) async {
    when(() => harness.repository.unlock('t1'))
        .thenAnswer((_) async => const LoginResult.twoFactorRequired('c1'));

    await pump(tester, token: 't1');

    expect(find.text(routeMarker(AppRoutes.twoFactor, 'c1')), findsOneWidget);
  });

  testWidgets('explains an invalid link', (tester) async {
    when(() => harness.repository.unlock('t1'))
        .thenThrow(const ApiError(code: 'invalid_unlock_token'));

    await pump(tester, token: 't1');

    expect(find.text(invalid), findsOneWidget);
  });

  testWidgets('offers a new password when the token is missing', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text(invalid), findsOneWidget);
    verifyZeroInteractions(harness.repository);

    await tester.tap(find.text('Criar uma nova senha'));
    await tester.pumpAndSettle();

    expect(find.text(routeMarker(AppRoutes.forgotPassword)), findsOneWidget);
  });

  testWidgets('goes back to the login', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Voltar para o login'));
    await tester.pumpAndSettle();

    expect(find.text(routeMarker(AppRoutes.login)), findsOneWidget);
  });
}
