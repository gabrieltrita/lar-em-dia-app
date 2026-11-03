import 'package:lar_em_dia/features/balance/domain/balance.dart';

abstract interface class BalanceRepository {
  Future<List<Balance>> list();

  Future<Balance?> latest();

  Future<Balance> create({required int amountCents, required DateTime asOf});

  Future<Balance> update(
    String id, {
    required int amountCents,
    required DateTime asOf,
  });

  Future<void> delete(String id);
}
