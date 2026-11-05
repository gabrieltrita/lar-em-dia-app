import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/features/auth/domain/auth_repository.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';
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
