import 'dart:async';

import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/session/session_events.dart';
import 'package:lar_em_dia/features/auth/domain/auth_repository.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';
import 'package:lar_em_dia/features/auth/domain/google_auth_gateway.dart';
import 'package:lar_em_dia/features/auth/domain/registration.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/auth_cubits.dart';
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

class FakeGoogleAuth implements GoogleAuthGateway {
  new({this.enabled = true, this.rendersOwnButton = false});

  final _tokens = StreamController<String>.broadcast();
  ApiError? failure;
  int signIns = 0;

  @override
  final bool enabled;

  @override
  final bool rendersOwnButton;

  @override
  Stream<String> get idTokens => _tokens.stream;

  void emit(String idToken) => _tokens.add(idToken);

  @override
  Future<void> signIn() async {
    signIns++;
    if (failure case final error?) {
      throw error;
    }
  }

  Future<void> dispose() => _tokens.close();
}

class AuthHarness {
  final repository = MockAuthRepository();
  final events = SessionEvents();
  final google = FakeGoogleAuth();
  late final session = SessionCubit(repository, events);

  GoogleSignInCubit googleCubit() => GoogleSignInCubit(repository, google);

  Future<void> dispose() async {
    await session.close();
    await events.dispose();
    await google.dispose();
  }
}
