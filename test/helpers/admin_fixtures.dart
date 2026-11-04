import 'package:lar_em_dia/features/admin/domain/admin_repository.dart';
import 'package:lar_em_dia/features/admin/domain/admin_user.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';
import 'package:mocktail/mocktail.dart';

class MockAdminRepository extends Mock implements AdminRepository;

const rafaelAdmin = AuthUser(
  id: 'admin-1',
  email: 'rafael@example.com',
  firstName: 'Rafael',
  twoFactorEnabled: true,
  role: UserRole.admin,
);

final carla = AdminUser(
  id: 'user-2',
  email: 'carla@example.com',
  fullName: 'Carla Lima',
  role: UserRole.user,
  emailConfirmed: true,
  twoFactorEnabled: false,
  locked: false,
  deactivated: false,
  signInCount: 4,
  createdAt: DateTime.utc(2026, 10, 1, 12),
  lastSignInAt: DateTime.utc(2026, 11, 3, 13, 30),
);

final bruno = AdminUser(
  id: 'user-3',
  email: 'bruno@example.com',
  fullName: 'Bruno Dias',
  role: UserRole.admin,
  emailConfirmed: false,
  twoFactorEnabled: true,
  locked: true,
  deactivated: true,
  signInCount: 0,
  createdAt: DateTime.utc(2026, 10, 2, 12),
);

final rafaelRecord = AdminUser(
  id: rafaelAdmin.id,
  email: rafaelAdmin.email,
  fullName: 'Rafael Souza',
  role: UserRole.admin,
  emailConfirmed: true,
  twoFactorEnabled: true,
  locked: false,
  deactivated: false,
  signInCount: 9,
  createdAt: DateTime.utc(2026, 9, 1, 12),
);

void registerAdminFallbacks() {
  registerFallbackValue(UserRole.user);
}
