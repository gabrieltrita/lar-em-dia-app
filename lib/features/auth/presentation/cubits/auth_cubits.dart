import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/auth/domain/auth_repository.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';
import 'package:lar_em_dia/features/auth/domain/google_auth_gateway.dart';
import 'package:lar_em_dia/features/auth/domain/login_result.dart';
import 'package:lar_em_dia/features/auth/domain/registration.dart';

@injectable
class LoginCubit extends SubmissionCubit<LoginResult> {
  new(this._repository);

  final AuthRepository _repository;

  Future<void> submit({required String email, required String password}) =>
      run(() => _repository.login(email: email, password: password));
}

@injectable
class GoogleSignInCubit extends SubmissionCubit<LoginResult> {
  new(this._repository, this._google);

  final AuthRepository _repository;
  final GoogleAuthGateway _google;
  late String _idToken;

  bool get enabled => _google.enabled;

  bool get rendersOwnButton => _google.rendersOwnButton;

  Stream<String> get idTokens => _google.idTokens;

  Future<void> start() async {
    try {
      await _google.signIn();
    } on ApiError catch (error) {
      emit(Submission.failure(error));
    }
  }

  Future<void> submit(String idToken) {
    _idToken = idToken;
    return run(() => _repository.signInWithGoogle(idToken));
  }

  Future<void> acceptConsents() =>
      run(() => _repository.signInWithGoogle(_idToken, acceptConsents: true));

  static bool needsConsents(ApiError error) =>
      error.code == 'validation_failed' &&
      error.details.containsKey('accept_terms');
}

@injectable
class TwoFactorCubit extends SubmissionCubit<AuthUser> {
  new(this._repository);

  final AuthRepository _repository;

  Future<void> submit({required String challengeToken, required String code}) =>
      run(
        () => _repository.verifyTwoFactor(
          challengeToken: challengeToken,
          code: code,
        ),
      );
}

@injectable
class RegisterCubit extends SubmissionCubit<String> {
  new(this._repository);

  final AuthRepository _repository;

  Future<void> submit(Registration registration) => run(() async {
    await _repository.register(registration);
    return registration.email;
  });
}

@injectable
class ResendConfirmationCubit extends SubmissionCubit<void> {
  new(this._repository);

  final AuthRepository _repository;

  Future<void> submit(String email) =>
      run(() => _repository.resendConfirmation(email));
}

@injectable
class ConfirmEmailCubit extends SubmissionCubit<AuthUser> {
  new(this._repository);

  final AuthRepository _repository;

  Future<void> submit(String token) =>
      run(() => _repository.confirmEmail(token));
}

@injectable
class UnlockCubit extends SubmissionCubit<LoginResult> {
  new(this._repository);

  final AuthRepository _repository;

  Future<void> submit(String token) => run(() => _repository.unlock(token));
}

@injectable
class ForgotPasswordCubit extends SubmissionCubit<void> {
  new(this._repository);

  final AuthRepository _repository;

  Future<void> submit(String email) =>
      run(() => _repository.requestPasswordReset(email));
}

@injectable
class ResetPasswordCubit extends SubmissionCubit<void> {
  new(this._repository);

  final AuthRepository _repository;

  Future<void> submit({required String token, required String password}) =>
      run(() => _repository.resetPassword(token: token, password: password));
}
