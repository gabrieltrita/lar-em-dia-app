import 'package:lar_em_dia/core/session/session_events.dart';
import 'package:lar_em_dia/features/auth/domain/auth_repository.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';
import 'package:lar_em_dia/features/auth/domain/registration.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository;

const ana = AuthUser(
  id: 'user-1',
  email: 'ana@example.com',
  firstName: 'Ana',
  twoFactorEnabled: false,
);

const anaRegistration = Registration(
  firstName: 'Ana',
  lastName: 'Souza',
  email: 'ana@example.com',
  password: 'Secret123',
  acceptTerms: true,
  acceptPrivacy: true,
);

void registerAuthFallbacks() {
  registerFallbackValue(anaRegistration);
}

class AuthHarness {
  final repository = MockAuthRepository();
  final events = SessionEvents();
  late final session = SessionCubit(repository, events);

  Future<void> dispose() async {
    await session.close();
    await events.dispose();
  }
}
