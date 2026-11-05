import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/security/presentation/cubits/security_cubits.dart';
import 'package:lar_em_dia/features/security/presentation/pages/two_factor_enrollment_page.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../helpers/clipboard.dart';
import '../../../../helpers/security_fixtures.dart';

void main() {
  late MockSecurityRepository repository;
  late List<Object?> popped;

  setUpAll(registerSecurityFallbacks);

  setUp(() {
    repository = MockSecurityRepository();
    popped = [];
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    addTearDown(tester.view.resetPhysicalSize);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => TextButton(
            onPressed: () async =>
                popped.add(await context.push<bool>('/enroll')),
            child: const Text('open'),
          ),
        ),
        GoRoute(
          path: '/enroll',
          builder: (_, _) => BlocProvider(
            create: (_) => TwoFactorEnrollmentCubit(repository),
            child: const TwoFactorEnrollmentPage(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> submitPassword(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('enrollment_password')),
      'Secret123',
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows why the password was refused', (tester) async {
    when(() => repository.setupTwoFactor(any()))
        .thenThrow(const ApiError(code: 'invalid_current_password'));
    await pump(tester);

    await submitPassword(tester);

    expect(find.text('Senha atual incorreta.'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('enrolls with the code and returns enabled', (tester) async {
    when(() => repository.setupTwoFactor(any()))
        .thenAnswer((_) async => twoFactorSetup);
    when(() => repository.enableTwoFactor(any()))
        .thenAnswer((_) async => backupCodes);
    final copied = recordClipboard(tester);
    await pump(tester);

    await submitPassword(tester);
    verify(() => repository.setupTwoFactor(passwordOnly)).called(1);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'QR code para o app autenticador',
      ),
      findsOneWidget,
    );
    expect(find.text(twoFactorSetup.secret), findsOneWidget);

    await tester.tap(find.byTooltip('Copiar chave'));
    await tester.pumpAndSettle();
    expect(copied, [twoFactorSetup.secret]);
    expect(find.text('Copiado.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('enrollment_code')),
      ' 123456 ',
    );
    await tester.tap(find.text('Ativar verificação'));
    await tester.pumpAndSettle();
    verify(() => repository.enableTwoFactor('123456')).called(1);
    expect(find.text(backupCodes.join('\n')), findsOneWidget);

    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(popped, [true]);
    expect(find.byType(TwoFactorEnrollmentPage), findsNothing);
  });

  testWidgets('shows why the code was refused', (tester) async {
    when(() => repository.setupTwoFactor(any()))
        .thenAnswer((_) async => twoFactorSetup);
    when(() => repository.enableTwoFactor(any()))
        .thenThrow(const ApiError(code: 'invalid_two_factor_code'));
    await pump(tester);

    await submitPassword(tester);
    await tester.enterText(find.byKey(const Key('enrollment_code')), '000000');
    await tester.tap(find.text('Ativar verificação'));
    await tester.pumpAndSettle();

    expect(find.text('Código incorreto.'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });
}
