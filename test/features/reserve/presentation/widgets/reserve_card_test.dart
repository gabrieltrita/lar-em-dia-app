import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve.dart';
import 'package:lar_em_dia/features/reserve/presentation/widgets/reserve_card.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/pump_page.dart';
import '../../../../helpers/reserve_fixtures.dart';

void main() {
  late AuthHarness harness;

  setUpAll(registerReserveFallbacks);
  setUp(() => harness = AuthHarness());
  tearDown(() => harness.dispose());

  Future<void> pump(
    WidgetTester tester, {
    ReserveSummary summary = emptyReserve,
    MockReserveDismissal? dismissal,
    bool alwaysShow = false,
  }) {
    tester.view.physicalSize = const Size(640, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    return pumpPage(
      tester,
      withReserveCard(
        Scaffold(
          body: ReserveCardView(
            alwaysShow: alwaysShow,
            padding: const EdgeInsets.all(16),
          ),
        ),
        summary: summary,
        dismissal: dismissal,
        now: DateTime(2026, 11, 12),
      ),
      session: harness.session,
    );
  }

  final card = find.byKey(const Key('reserve_card'));

  testWidgets('shows the net total, the coverage and the accounts', (
    tester,
  ) async {
    await pump(tester, summary: reserveSummary);

    expect(find.text(r'R$ 13.900,00'), findsOneWidget);
    expect(find.text('4,5 de 6 meses'), findsOneWidget);
    expect(find.text('Tesouro Selic'), findsOneWidget);
    expect(find.text(r'R$ 12.400,00'), findsOneWidget);
    expect(find.text('Conta corrente'), findsOneWidget);

    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text(routeMarker(AppRoutes.reserve)), findsOneWidget);
  });

  testWidgets('shows the totals without a suggestion', (tester) async {
    await pump(tester, summary: reserveSummary.copyWith(suggestion: null));

    expect(find.text(r'R$ 13.900,00'), findsOneWidget);
    expect(find.textContaining('de 6 meses'), findsNothing);
  });

  testWidgets('invites to inform a reserve and can be dismissed', (
    tester,
  ) async {
    final dismissal = dismissalUntil(null);
    await pump(tester, summary: noReserve, dismissal: dismissal);

    expect(
      find.text(
        'Você ainda não informou uma reserva de emergência. Uma referência '
        r'comum é ter de 3 a 6 meses dos seus custos fixos (R$ 3.100,00 por '
        'mês).',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();

    verify(() => dismissal.dismiss(any())).called(1);
    expect(card, findsNothing);
  });

  testWidgets('opens the reserve from the invitation', (tester) async {
    await pump(tester, summary: noReserve);

    await tester.tap(find.text('Informar reserva'));
    await tester.pumpAndSettle();

    expect(find.text(routeMarker(AppRoutes.reserve)), findsOneWidget);
  });

  testWidgets('stays hidden while dismissed or without fixed expenses', (
    tester,
  ) async {
    await pump(
      tester,
      summary: noReserve,
      dismissal: dismissalUntil(DateTime(2026, 12)),
    );
    expect(card, findsNothing);

    await pump(tester);
    expect(card, findsNothing);
  });

  testWidgets('always introduces the reserve on the investments tab', (
    tester,
  ) async {
    await pump(tester, summary: noReserve, alwaysShow: true);

    expect(find.textContaining('cobre imprevistos'), findsOneWidget);
    expect(find.text('Agora não'), findsNothing);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text(routeMarker(AppRoutes.reserve)), findsOneWidget);
  });
}
