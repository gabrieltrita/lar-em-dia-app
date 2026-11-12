import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';
import 'package:lar_em_dia/features/reserve/data/reserve_dtos.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve_repository.dart';

@LazySingleton(as: ReserveRepository)
class ApiReserveRepository implements ReserveRepository {
  new(this._client, this._cache);

  static const reservePath = '/reserve';
  static const accountsPath = '/reserve_accounts';
  static const movementsPath = '/reserve_movements';
  static const movementsLimit = 100;

  final ApiClient _client;
  final FinanceCache _cache;

  @override
  Future<ReserveSummary> summary() async {
    final response = await _client.get<ReserveSummary>(
      reservePath,
      decode: _summary,
    );
    return response.data;
  }

  @override
  Future<ReserveSummary> updateGoal({required int months, int? cents}) async {
    final response = await _client.patch<ReserveSummary>(
      reservePath,
      decode: _summary,
      body: {'goal_months': months, 'goal_cents': cents},
    );
    return response.data;
  }

  @override
  Future<ReserveProjection> projection(int months) async {
    final response = await _client.get<ReserveProjection>(
      '$reservePath/projection',
      decode: (data) => ReserveProjectionDto.fromJson(data! as Json).toDomain(),
      query: {'months': months},
    );
    return response.data;
  }

  @override
  Future<ReserveAccount> createAccount(ReserveAccountDraft draft) async {
    final response = await _client.post<ReserveAccount>(
      accountsPath,
      decode: _account,
      body: _accountBody(draft),
    );
    return response.data;
  }

  @override
  Future<ReserveAccount> updateAccount(
    String id,
    ReserveAccountDraft draft,
  ) async {
    final response = await _client.patch<ReserveAccount>(
      '$accountsPath/$id',
      decode: _account,
      body: _accountBody(draft),
    );
    return response.data;
  }

  @override
  Future<void> deleteAccount(String id) async {
    await _client.delete('$accountsPath/$id');
    _cache.clear();
  }

  @override
  Future<List<ReserveMovement>> movements(String accountId) async {
    final response = await _client.get<List<ReserveMovement>>(
      movementsPath,
      decode: (data) => [
        for (final item in data! as List<dynamic>) _movement(item),
      ],
      query: {'account_id': accountId, 'limit': movementsLimit},
    );
    return response.data;
  }

  @override
  Future<ReserveMovement> createMovement(ReserveMovementDraft draft) async {
    final response = await _client.post<ReserveMovement>(
      movementsPath,
      decode: _movement,
      body: {'account_id': draft.accountId, ..._movementBody(draft)},
    );
    _changed(_debits(draft));
    return response.data;
  }

  @override
  Future<ReserveMovement> updateMovement(
    ReserveMovement existing,
    ReserveMovementDraft draft,
  ) async {
    final response = await _client.patch<ReserveMovement>(
      '$movementsPath/${existing.id}',
      decode: _movement,
      body: _movementBody(draft),
    );
    _changed(existing.changesBalance || _debits(draft));
    return response.data;
  }

  @override
  Future<void> deleteMovement(ReserveMovement movement) async {
    await _client.delete('$movementsPath/${movement.id}');
    _changed(movement.changesBalance);
  }

  void _changed(bool balance) {
    if (balance) {
      _cache.clear();
    }
  }

  static Json _accountBody(ReserveAccountDraft draft) => {
    'name': draft.name,
    'kind': ReserveWire.kind(draft.kind),
    'cdi_percent_bps': draft.kind.usesCdiPercent ? draft.cdiPercentBps : null,
    'annual_rate_bps': draft.kind.usesAnnualRate ? draft.annualRateBps : null,
    'tax_exempt': draft.kind.canBeExempt && draft.taxExempt,
  };

  static bool _debits(ReserveMovementDraft draft) =>
      draft.kind.changesBalance && draft.debitBalance;

  static Json _movementBody(ReserveMovementDraft draft) => {
    'kind': draft.kind.name,
    'moved_on': Dates.toIso(draft.movedOn),
    'amount_cents': draft.amountCents,
    'debit_balance': _debits(draft),
  };

  static ReserveSummary _summary(Object? data) =>
      ReserveSummaryDto.fromJson(data! as Json).toDomain();

  static ReserveAccount _account(Object? data) =>
      ReserveAccountDto.fromJson(data! as Json).toDomain();

  static ReserveMovement _movement(Object? data) =>
      ReserveMovementDto.fromJson(data! as Json).toDomain();
}
