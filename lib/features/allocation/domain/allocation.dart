import 'package:freezed_annotation/freezed_annotation.dart';

part 'allocation.freezed.dart';

enum AllocationMode { fixed, percent, remainder }

@freezed
abstract class AllocationTarget with _$AllocationTarget {
  const factory({
    required String id,
    required String name,
    required AllocationMode mode,
    int? amountCents,
    int? percentBps,
    String? reserveAccountId,
    @Default(0) int position,
  }) = _AllocationTarget;
}

@freezed
abstract class AllocationTargetDraft with _$AllocationTargetDraft {
  const factory({
    required String name,
    required AllocationMode mode,
    int? amountCents,
    int? percentBps,
    String? reserveAccountId,
  }) = _AllocationTargetDraft;
}

@freezed
abstract class AllocationItem with _$AllocationItem {
  const factory({
    required String targetId,
    required String name,
    required AllocationMode mode,
    required int amountCents,
    int? percentBps,
    String? reserveAccountId,
    @Default(false) bool used,
    String? allocationId,
    DateTime? usedOn,
  }) = _AllocationItem;
}

@freezed
abstract class AllocationPlan with _$AllocationPlan {
  const factory({
    required DateTime month,
    required int closingCents,
    required int baseCents,
    required int usedCents,
    required int plannedCents,
    required int unallocatedCents,
    @Default([]) List<AllocationItem> items,
  }) = _AllocationPlan;

  const new _();

  bool get hasRemainder =>
      items.any((item) => item.mode == AllocationMode.remainder);
}
