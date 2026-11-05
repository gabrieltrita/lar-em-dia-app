import 'package:freezed_annotation/freezed_annotation.dart';

part 'registration.freezed.dart';

@freezed
abstract class Registration with _$Registration {
  const factory({
    required String firstName,
    required String email,
    required String password,
    required bool acceptTerms,
    required bool acceptPrivacy,
    String? lastName,
  }) = _Registration;
}
