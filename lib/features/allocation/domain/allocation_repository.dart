import 'package:lar_em_dia/features/allocation/domain/allocation.dart';

abstract interface class AllocationRepository {
  Future<AllocationPlan> plan(DateTime month);

  Future<List<AllocationTarget>> targets();

  Future<AllocationTarget> createTarget(AllocationTargetDraft draft);

  Future<AllocationTarget> updateTarget(String id, AllocationTargetDraft draft);

  Future<void> deleteTarget(String id);

  Future<void> use(String targetId, DateTime month, {int? amountCents});

  Future<void> undo(String allocationId);
}
