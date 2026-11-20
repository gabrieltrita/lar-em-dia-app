import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/features/allocation/domain/allocation.dart';

part 'allocation_dtos.freezed.dart';
part 'allocation_dtos.g.dart';

@freezed
abstract class AllocationTargetDto with _$AllocationTargetDto {
  const factory({
    required String id,
    required String name,
    required String mode,
    int? amountCents,
    int? percentBps,
    String? reserveAccountId,
    @Default(0) int position,
  }) = _AllocationTargetDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$AllocationTargetDtoFromJson(json);

  AllocationTarget toDomain() => AllocationTarget(
    id: id,
    name: name,
    mode: AllocationMode.values.byName(mode),
    amountCents: amountCents,
    percentBps: percentBps,
    reserveAccountId: reserveAccountId,
    position: position,
  );
}

@freezed
abstract class AllocationItemDto with _$AllocationItemDto {
  const factory({
    required String targetId,
    required String name,
    required String mode,
    required int amountCents,
    int? percentBps,
    String? reserveAccountId,
    @Default(false) bool used,
    String? allocationId,
    String? usedOn,
  }) = _AllocationItemDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$AllocationItemDtoFromJson(json);

  AllocationItem toDomain() => AllocationItem(
    targetId: targetId,
    name: name,
    mode: AllocationMode.values.byName(mode),
    amountCents: amountCents,
    percentBps: percentBps,
    reserveAccountId: reserveAccountId,
    used: used,
    allocationId: allocationId,
    usedOn: usedOn == null ? null : Dates.parseIso(usedOn!),
  );
}

@freezed
abstract class AllocationPlanDto with _$AllocationPlanDto {
  const factory({
    required String month,
    required int closingCents,
    required int baseCents,
    required int usedCents,
    required int plannedCents,
    required int unallocatedCents,
    @Default([]) List<AllocationItemDto> items,
  }) = _AllocationPlanDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$AllocationPlanDtoFromJson(json);

  AllocationPlan toDomain() => AllocationPlan(
    month: Dates.parseMonth(month)!,
    closingCents: closingCents,
    baseCents: baseCents,
    usedCents: usedCents,
    plannedCents: plannedCents,
    unallocatedCents: unallocatedCents,
    items: [for (final item in items) item.toDomain()],
  );
}
