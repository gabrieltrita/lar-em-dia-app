import 'package:lar_em_dia/features/reserve/domain/reserve.dart';

abstract interface class ReserveRepository {
  Future<ReserveSummary> summary();

  Future<ReserveSummary> updateGoal({required int months, int? cents});

  Future<ReserveProjection> projection(int months);

  Future<ReserveAccount> createAccount(ReserveAccountDraft draft);

  Future<ReserveAccount> updateAccount(String id, ReserveAccountDraft draft);

  Future<void> deleteAccount(String id);

  Future<List<ReserveMovement>> movements(String accountId);

  Future<ReserveMovement> createMovement(ReserveMovementDraft draft);

  Future<ReserveMovement> updateMovement(
    ReserveMovement existing,
    ReserveMovementDraft draft,
  );

  Future<void> deleteMovement(ReserveMovement movement);
}
