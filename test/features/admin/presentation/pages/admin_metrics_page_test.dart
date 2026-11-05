import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/admin/domain/admin_metrics.dart';
import 'package:lar_em_dia/features/admin/presentation/cubits/admin_cubits.dart';
import 'package:lar_em_dia/features/admin/presentation/pages/admin_metrics_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/admin_fixtures.dart';
import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;
  late MockAdminRepository repository;

  setUp(() {
    harness = AuthHarness()..session.signedIn(rafaelAdmin);
    repository = MockAdminRepository();
  });
  tearDown(() => harness.dispose());

  Future<void> pump(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 3000);
    addTearDown(tester.view.resetPhysicalSize);
    return pumpPage(
      tester,
      BlocProvider(
        create: (_) =>
            started(AdminMetricsCubit(repository), (cubit) => cubit.load()),
        child: const AdminMetricsPage(),
      ),
      session: harness.session,
    );
  }

  testWidgets('shows the counts and the weekly sign ups', (tester) async {
    when(repository.metrics).thenAnswer(
      (_) async => metrics.copyWith(
        signupsByWeek: [
          for (var week = 0; week < 12; week++)
            WeeklySignups(
              week: DateTime(2026, 8, 31).add(Duration(days: 7 * week)),
              count: week,
            ),
        ],
      ),
    );
    await pump(tester);

    for (final (label, value) in [
      ('Total', '42'),
      ('Ativas em 30 dias', '31'),
      ('Com 2FA', '5'),
      ('Têm 5 ou mais séries', '19'),
      ('Lançamentos em 30 dias', '512'),
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
      expect(find.text(value), findsWidgets, reason: label);
    }
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('31/08'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Gráfico de cadastros')),
      findsOneWidget,
    );
  });

  testWidgets('retries a failed load and reloads on pull', (tester) async {
    when(repository.metrics).thenThrow(const ApiError(code: 'forbidden'));
    await pump(tester);

    expect(
      find.text('Você não tem permissão para fazer isso.'),
      findsOneWidget,
    );

    when(repository.metrics).thenAnswer((_) async => metrics);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(find.text('512'), findsOneWidget);

    await tester.fling(find.text('Total'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    verify(repository.metrics).called(3);
  });
}
