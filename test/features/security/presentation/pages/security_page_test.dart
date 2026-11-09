import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/security/domain/two_factor.dart';
import 'package:lar_em_dia/features/security/presentation/cubits/security_cubits.dart';
import 'package:lar_em_dia/features/security/presentation/pages/security_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/pump_page.dart';
import '../../../../helpers/security_fixtures.dart';

void main() {
  late AuthHarness harness;
  late MockSecurityRepository repository;

  setUpAll(registerSecurityFallbacks);

  setUp(() {
    harness = AuthHarness()..session.signedIn(ana);
    repository = MockSecurityRepository();
  });
  tearDown(() => harness.dispose());

  bool sessionTwoFactor() => switch (harness.session.state) {
    SessionAuthenticated(:final user) => user.twoFactorEnabled,
    _ => throw StateError('signed out'),
  };

  Future<void> pump(WidgetTester tester) => pumpPage(
    tester,
    BlocProvider(
      create: (_) =>
          started(SecurityCubit(repository), (cubit) => cubit.load()),
      child: const SecurityPage(),
    ),
    session: harness.session,
  );

  Future<void> reauthenticate(WidgetTester tester, String action) async {
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('reauth_password')),
      'Secret123',
    );
    await tester.enterText(find.byKey(const Key('reauth_code')), ' 123456 ');
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
  }

  testWidgets('links to the due-date alerts', (tester) async {
    when(() => repository.twoFactorStatus())
        .thenAnswer((_) async => twoFactorOff);
    await pump(tester);

    expect(find.text('Conta'), findsOneWidget);
    await tester.tap(find.text('Alertas de vencimento'));
    await tester.pumpAndSettle();

    expect(
      find.text(routeMarker(AppRoutes.notificationSettings)),
      findsOneWidget,
    );
  });

  testWidgets('offers to enable two-factor when it is off', (tester) async {
    when(() => repository.twoFactorStatus())
        .thenAnswer((_) async => twoFactorOff);
    await pump(tester);

    expect(find.textContaining('Desativada.'), findsOneWidget);
    expect(find.text('Ativar'), findsOneWidget);
    expect(find.text('Desativar'), findsNothing);
    expect(find.text('Gerar novos códigos de recuperação'), findsNothing);
  });

  testWidgets('marks the session after enrolling', (tester) async {
    when(() => repository.twoFactorStatus())
        .thenAnswer((_) async => twoFactorOff);
    await pump(tester);

    await tester.tap(find.text('Ativar'));
    await tester.pumpAndSettle();
    expect(
      find.text(routeMarker(AppRoutes.twoFactorEnrollment)),
      findsOneWidget,
    );
    when(() => repository.twoFactorStatus())
        .thenAnswer((_) async => twoFactorOn);
    await tester.tap(find.text(savedAndBack));
    await tester.pumpAndSettle();

    expect(sessionTwoFactor(), isTrue);
    expect(find.textContaining('10 códigos'), findsOneWidget);
  });

  testWidgets('keeps the session when the enrollment is closed', (
    tester,
  ) async {
    when(() => repository.twoFactorStatus())
        .thenAnswer((_) async => twoFactorOff);
    await pump(tester);

    await tester.tap(find.text('Ativar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(closedAndBack));
    await tester.pumpAndSettle();

    expect(sessionTwoFactor(), isFalse);
    verify(() => repository.twoFactorStatus()).called(2);
  });

  testWidgets('disables two-factor after reauthentication', (tester) async {
    harness.session.signedIn(ana.copyWith(twoFactorEnabled: true));
    when(() => repository.twoFactorStatus())
        .thenAnswer((_) async => twoFactorOn);
    when(() => repository.disableTwoFactor(any())).thenAnswer((_) async {});
    await pump(tester);

    await reauthenticate(tester, 'Desativar');

    verify(() => repository.disableTwoFactor(passwordAndCode)).called(1);
    expect(sessionTwoFactor(), isFalse);
  });

  testWidgets('shows why disabling failed', (tester) async {
    harness.session.signedIn(ana.copyWith(twoFactorEnabled: true));
    when(() => repository.twoFactorStatus())
        .thenAnswer((_) async => twoFactorOn);
    when(() => repository.disableTwoFactor(any()))
        .thenThrow(const ApiError(code: 'invalid_current_password'));
    await pump(tester);

    await reauthenticate(tester, 'Desativar');

    expect(find.text('Senha atual incorreta.'), findsOneWidget);
    expect(sessionTwoFactor(), isTrue);
  });

  testWidgets('does nothing when the reauthentication is cancelled', (
    tester,
  ) async {
    when(() => repository.twoFactorStatus())
        .thenAnswer((_) async => twoFactorOn);
    await pump(tester);

    for (final action in ['Desativar', 'Gerar novos códigos de recuperação']) {
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
    }

    verifyNever(() => repository.disableTwoFactor(any()));
    verifyNever(() => repository.regenerateBackupCodes(any()));
  });

  testWidgets('shows new backup codes in a dialog', (tester) async {
    when(() => repository.twoFactorStatus())
        .thenAnswer((_) async => twoFactorOn);
    when(() => repository.regenerateBackupCodes(any()))
        .thenAnswer((_) async => backupCodes);
    await pump(tester);

    await reauthenticate(tester, 'Gerar novos códigos de recuperação');

    expect(find.text(backupCodes.join('\n')), findsOneWidget);
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('shows why new backup codes failed', (tester) async {
    when(() => repository.twoFactorStatus())
        .thenAnswer((_) async => twoFactorOn);
    when(() => repository.regenerateBackupCodes(any()))
        .thenThrow(const ApiError(code: 'invalid_two_factor_code'));
    await pump(tester);

    await reauthenticate(tester, 'Gerar novos códigos de recuperação');

    expect(find.text('Código incorreto.'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('hides disabling when two-factor is mandatory', (tester) async {
    when(() => repository.twoFactorStatus()).thenAnswer(
      (_) async => const TwoFactorStatus(
        enabled: true,
        mandatory: true,
        backupCodesRemaining: 3,
      ),
    );
    await pump(tester);

    expect(find.text('Obrigatória para administradores.'), findsOneWidget);
    expect(find.text('Desativar'), findsNothing);
    expect(find.text('Gerar novos códigos de recuperação'), findsOneWidget);
  });

  testWidgets('retries after a failed load', (tester) async {
    when(() => repository.twoFactorStatus())
        .thenThrow(const ApiError(code: ApiError.networkErrorCode));
    await pump(tester);
    expect(
      find.text('Não foi possível conectar. Verifique sua internet.'),
      findsOneWidget,
    );

    when(() => repository.twoFactorStatus())
        .thenAnswer((_) async => twoFactorOff);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('Ativar'), findsOneWidget);
  });

  group('deleting the account', () {
    Future<void> startDeletion(WidgetTester tester) async {
      when(() => repository.twoFactorStatus())
          .thenAnswer((_) async => twoFactorOff);
      await pump(tester);
      await tester.scrollUntilVisible(find.text('Excluir conta'), 100);
      await tester.tap(find.text('Excluir conta'));
      await tester.pumpAndSettle();
    }

    testWidgets('warns, reauthenticates, deletes and signs out', (
      tester,
    ) async {
      when(() => repository.deleteAccount(any())).thenAnswer((_) async {});
      when(() => harness.repository.logout()).thenAnswer((_) async {});
      await startDeletion(tester);

      expect(find.textContaining('apagados para sempre'), findsOneWidget);
      await reauthenticate(tester, 'Continuar');

      verify(() => repository.deleteAccount(passwordAndCode)).called(1);
      verify(() => harness.repository.logout()).called(1);
      expect(harness.session.state, const SessionState.unauthenticated());
      expect(find.text('Sua conta foi excluída.'), findsOneWidget);
    });

    testWidgets('keeps the session when the deletion fails', (tester) async {
      when(() => repository.deleteAccount(any()))
          .thenThrow(const ApiError(code: 'invalid_current_password'));
      await startDeletion(tester);

      await reauthenticate(tester, 'Continuar');

      expect(find.text('Senha atual incorreta.'), findsOneWidget);
      expect(harness.session.state, isA<SessionAuthenticated>());
      verifyNever(() => harness.repository.logout());
    });

    testWidgets('does nothing when the warning is cancelled', (tester) async {
      await startDeletion(tester);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => repository.deleteAccount(any()));
    });

    testWidgets('does nothing when the reauthentication is cancelled', (
      tester,
    ) async {
      await startDeletion(tester);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      verifyNever(() => repository.deleteAccount(any()));
    });
  });
}
