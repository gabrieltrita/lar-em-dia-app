import 'package:lar_em_dia/features/allocation/domain/allocation.dart';
import 'package:lar_em_dia/features/allocation/domain/allocation_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockAllocationRepository extends Mock implements AllocationRepository;

const fixedIncome = AllocationTarget(
  id: 'target-1',
  name: 'Renda fixa',
  mode: AllocationMode.percent,
  percentBps: 1000,
  position: 1,
);

const charity = AllocationTarget(
  id: 'target-2',
  name: 'Caridade',
  mode: AllocationMode.fixed,
  amountCents: 1000,
  position: 2,
);

const reserveTarget = AllocationTarget(
  id: 'target-3',
  name: 'Reserva',
  mode: AllocationMode.remainder,
  reserveAccountId: 'reserve-account-1',
  position: 3,
);

const List<AllocationTarget> allocationTargets = [
  fixedIncome,
  charity,
  reserveTarget,
];

final novemberPlan = AllocationPlan(
  month: DateTime(2026, 11),
  closingCents: 8400,
  baseCents: 9400,
  usedCents: 1000,
  plannedCents: 9400,
  unallocatedCents: 0,
  items: [
    const AllocationItem(
      targetId: 'target-1',
      name: 'Renda fixa',
      mode: AllocationMode.percent,
      amountCents: 940,
      percentBps: 1000,
    ),
    AllocationItem(
      targetId: 'target-2',
      name: 'Caridade',
      mode: AllocationMode.fixed,
      amountCents: 1000,
      used: true,
      allocationId: 'allocation-1',
      usedOn: DateTime(2026, 11, 20),
    ),
    const AllocationItem(
      targetId: 'target-3',
      name: 'Reserva',
      mode: AllocationMode.remainder,
      amountCents: 7460,
      reserveAccountId: 'reserve-account-1',
    ),
  ],
);

const targetDraft = AllocationTargetDraft(
  name: 'Renda fixa',
  mode: AllocationMode.percent,
  percentBps: 1000,
);

void registerAllocationFallbacks() {
  registerFallbackValue(targetDraft);
  registerFallbackValue(DateTime(2026));
}

MockAllocationRepository allocationRepositoryWith(AllocationPlan plan) {
  final repository = MockAllocationRepository();
  when(() => repository.plan(any())).thenAnswer((_) async => plan);
  when(repository.targets).thenAnswer((_) async => allocationTargets);
  when(
    () => repository.use(any(), any(), amountCents: any(named: 'amountCents')),
  ).thenAnswer((_) async {});
  when(() => repository.undo(any())).thenAnswer((_) async {});
  when(() => repository.deleteTarget(any())).thenAnswer((_) async {});
  when(() => repository.createTarget(any()))
      .thenAnswer((_) async => fixedIncome);
  when(() => repository.updateTarget(any(), any()))
      .thenAnswer((_) async => fixedIncome);
  return repository;
}
