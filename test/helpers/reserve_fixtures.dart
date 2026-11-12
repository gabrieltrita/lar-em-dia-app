import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve_dismissal.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve_repository.dart';
import 'package:lar_em_dia/features/reserve/presentation/cubits/reserve_cubits.dart';
import 'package:mocktail/mocktail.dart';

import 'pump_page.dart';

class MockReserveRepository extends Mock implements ReserveRepository;

class MockReserveDismissal extends Mock implements ReserveDismissal;

const treasuryValue = ReserveValue(
  grossCents: 1250000,
  netCents: 1240000,
  investedCents: 1200000,
  yieldCents: 50000,
  taxCents: 10000,
);

const idleValue = ReserveValue(
  grossCents: 150000,
  netCents: 150000,
  investedCents: 150000,
  yieldCents: 0,
  taxCents: 0,
);

const treasury = ReserveAccount(
  id: 'reserve-account-1',
  name: 'Tesouro Selic',
  kind: ReserveKind.selicTreasury,
  value: treasuryValue,
);

const cdb = ReserveAccount(
  id: 'reserve-account-2',
  name: 'CDB do banco',
  kind: ReserveKind.cdb,
  cdiPercentBps: 11000,
  taxExempt: true,
);

const idle = ReserveAccount(
  id: 'reserve-account-3',
  name: 'Conta corrente',
  kind: ReserveKind.idle,
  value: idleValue,
);

const reserveTotals = ReserveValue(
  grossCents: 1400000,
  netCents: 1390000,
  investedCents: 1350000,
  yieldCents: 50000,
  taxCents: 10000,
);

const suggestion = ReserveSuggestion(
  averageFixedCents: 310000,
  monthsCounted: 3,
  goalMonths: 6,
  suggestedCents: 1860000,
  coverageMonthsE2: 448,
);

final reserveSummary = ReserveSummary(
  totals: reserveTotals,
  accounts: const [treasury, idle],
  goal: const ReserveGoal(months: 6, targetCents: 1860000),
  suggestion: suggestion,
  alerts: const [ReserveAlert.belowSuggestion, ReserveAlert.idleMoney],
  ratesAsOf: DateTime(2026, 11, 11),
);

const emptyReserve = ReserveSummary(
  totals: ReserveValue.empty,
  accounts: [],
  goal: ReserveGoal(months: 6),
);

const noReserve = ReserveSummary(
  totals: ReserveValue.empty,
  accounts: [],
  goal: ReserveGoal(months: 6, targetCents: 1860000),
  suggestion: ReserveSuggestion(
    averageFixedCents: 310000,
    monthsCounted: 3,
    goalMonths: 6,
    suggestedCents: 1860000,
    coverageMonthsE2: 0,
  ),
  alerts: [ReserveAlert.noReserve],
);

final reserveProjection = ReserveProjection(
  months: [
    for (var index = 0; index < 12; index++)
      ReserveProjectionMonth(
        month: DateTime(2026, 11 + index),
        grossCents: 1400000 + index * 15000,
        netCents: 1390000 + index * 12000,
      ),
  ],
  assumptions: ReserveAssumptions(
    selicTargetE8: 13750000,
    cdiEstimateE8: 13650000,
    savingsMonthlyE8: 500000,
    ratesAsOf: DateTime(2026, 11, 11),
  ),
);

final anchorMovement = ReserveMovement(
  id: 'reserve-movement-1',
  accountId: treasury.id,
  kind: ReserveMovementKind.anchor,
  movedOn: DateTime(2026, 1, 5),
  amountCents: 1200000,
);

final depositMovement = ReserveMovement(
  id: 'reserve-movement-2',
  accountId: treasury.id,
  kind: ReserveMovementKind.deposit,
  movedOn: DateTime(2026, 7, 5),
  amountCents: 20000,
  entryId: 'entry-7',
);

final withdrawalMovement = ReserveMovement(
  id: 'reserve-movement-3',
  accountId: treasury.id,
  kind: ReserveMovementKind.withdrawal,
  movedOn: DateTime(2026, 9, 5),
  amountCents: 5000,
);

const treasuryDraft = ReserveAccountDraft(
  name: 'Tesouro Selic',
  kind: ReserveKind.selicTreasury,
);

final depositDraft = ReserveMovementDraft(
  accountId: treasury.id,
  kind: ReserveMovementKind.deposit,
  movedOn: DateTime(2026, 7, 5),
  amountCents: 20000,
  debitBalance: true,
);

void registerReserveFallbacks() {
  registerFallbackValue(treasuryDraft);
  registerFallbackValue(depositDraft);
  registerFallbackValue(depositMovement);
  registerFallbackValue(DateTime(2026));
}

MockReserveRepository reserveRepositoryWith(ReserveSummary summary) {
  final repository = MockReserveRepository();
  when(repository.summary).thenAnswer((_) async => summary);
  return repository;
}

MockReserveDismissal dismissalUntil(DateTime? until) {
  final dismissal = MockReserveDismissal();
  when(dismissal.dismissedUntil).thenAnswer((_) async => until);
  when(() => dismissal.dismiss(any())).thenAnswer((_) async {});
  return dismissal;
}

Widget withReserveCard(
  Widget child, {
  ReserveSummary summary = emptyReserve,
  ReserveRepository? repository,
  ReserveDismissal? dismissal,
  DateTime? now,
}) => BlocProvider(
  create: (_) => started(
    ReserveCardCubit(
      repository ?? reserveRepositoryWith(summary),
      dismissal ?? dismissalUntil(null),
    ),
    (cubit) => cubit.load(now: now),
  ),
  child: child,
);
