import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/confirm_email_page.dart';
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
          create: (_) => ConfirmEmailCubit(harness.repository),
          child: ConfirmEmailPage(token: token),
        ),
        session: harness.session,
        settle: settle,
      );

  const invalid = 'Este link de confirmação é inválido ou expirou.';

  testWidgets('confirms the email and signs the user in', (tester) async {
    when(() => harness.repository.confirmEmail('t1'))
        .thenAnswer((_) async => ana);

    await pump(tester, token: 't1', settle: false);
    await tester.pump();

    expect(harness.session.state, const SessionState.authenticated(ana));
  });

  testWidgets('explains an invalid link', (tester) async {
    when(() => harness.repository.confirmEmail('t1'))
        .thenThrow(const ApiError(code: 'invalid_confirmation_token'));

    await pump(tester, token: 't1');

    expect(find.text(invalid), findsOneWidget);
  });

  testWidgets('offers a new link when the token is missing', (tester) async {
    await pump(tester);
    expect(find.text(invalid), findsOneWidget);
    verifyZeroInteractions(harness.repository);

    await tester.tap(find.text('Pedir um novo link'));
    await tester.pumpAndSettle();

    expect(find.text(routeMarker(AppRoutes.checkEmail)), findsOneWidget);
  });

  testWidgets('goes back to the login', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Voltar para o login'));
    await tester.pumpAndSettle();

    expect(find.text(routeMarker(AppRoutes.login)), findsOneWidget);
  });
}
