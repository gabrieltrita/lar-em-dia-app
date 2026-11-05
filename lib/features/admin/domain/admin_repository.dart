import 'package:lar_em_dia/features/admin/domain/admin_category.dart';
import 'package:lar_em_dia/features/admin/domain/admin_metrics.dart';
import 'package:lar_em_dia/features/admin/domain/admin_user.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';

abstract interface class AdminRepository {
  Future<AdminUserPage> users({
    required int page,
    String? email,
    AccountStatus? status,
  });

  Future<AdminUser> user(String id);

  Future<AdminUser> unlock(String id);

  Future<void> resetTwoFactor(String id);

  Future<AdminUser> deactivate(String id);

  Future<AdminUser> reactivate(String id);

  Future<AdminUser> changeRole(String id, UserRole role);

  Future<AdminMetrics> metrics();

  Future<List<AdminCategory>> categories();

  Future<AdminCategory> createCategory(CategoryDraft draft);

  Future<AdminCategory> updateCategory(String id, CategoryDraft draft);
}
