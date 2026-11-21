import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/allocation/data/allocation_dtos.dart';
import 'package:lar_em_dia/features/allocation/domain/allocation.dart';
import 'package:lar_em_dia/features/allocation/domain/allocation_repository.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';

@LazySingleton(as: AllocationRepository)
class ApiAllocationRepository implements AllocationRepository {
  new(this._client, this._cache);

  static const planPath = '/allocation_plan';
  static const targetsPath = '/allocation_targets';
  static const allocationsPath = '/allocations';

  final ApiClient _client;
  final FinanceCache _cache;

  @override
  Future<AllocationPlan> plan(DateTime month) async {
    final response = await _client.get<AllocationPlan>(
      planPath,
      decode: (data) => AllocationPlanDto.fromJson(data! as Json).toDomain(),
      query: {'month': Dates.toMonth(month)},
    );
    return response.data;
  }

  @override
  Future<List<AllocationTarget>> targets() async {
    final response = await _client.get<List<AllocationTarget>>(
      targetsPath,
      decode: (data) => [
        for (final item in data! as List<dynamic>) _target(item),
      ],
    );
    return response.data;
  }

  @override
  Future<AllocationTarget> createTarget(AllocationTargetDraft draft) async {
    final response = await _client.post<AllocationTarget>(
      targetsPath,
      decode: _target,
      body: _targetBody(draft),
    );
    return response.data;
  }

  @override
  Future<AllocationTarget> updateTarget(
    String id,
    AllocationTargetDraft draft,
  ) async {
    final response = await _client.patch<AllocationTarget>(
      '$targetsPath/$id',
      decode: _target,
      body: _targetBody(draft),
    );
    return response.data;
  }

  @override
  Future<void> deleteTarget(String id) => _client.delete('$targetsPath/$id');

  @override
  Future<void> use(String targetId, DateTime month, {int? amountCents}) async {
    await _client.post<Object?>(
      allocationsPath,
      decode: (data) => data,
      body: {
        'target_id': targetId,
        'month': Dates.toMonth(month),
        'amount_cents': ?amountCents,
      },
    );
    _cache.clear();
  }

  @override
  Future<void> undo(String allocationId) async {
    await _client.delete('$allocationsPath/$allocationId');
    _cache.clear();
  }

  static Json _targetBody(AllocationTargetDraft draft) => {
    'name': draft.name,
    'mode': draft.mode.name,
    'amount_cents': draft.mode == AllocationMode.fixed
        ? draft.amountCents
        : null,
    'percent_bps': draft.mode == AllocationMode.percent
        ? draft.percentBps
        : null,
    'reserve_account_id': draft.reserveAccountId,
    'category_id': draft.categoryId,
  };

  static AllocationTarget _target(Object? data) =>
      AllocationTargetDto.fromJson(data! as Json).toDomain();
}
