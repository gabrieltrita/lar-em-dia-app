import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/forms/validators.dart';

void main() {
  test('required rejects null, empty and blank values', () {
    expect(Validators.required(null), ValidationError.required);
    expect(Validators.required(''), ValidationError.required);
    expect(Validators.required('  '), ValidationError.required);
    expect(Validators.required('Ana'), isNull);
  });

  test('email requires a value and a plausible address', () {
    expect(Validators.email(''), ValidationError.required);
    expect(Validators.email('ana'), ValidationError.invalidEmail);
    expect(Validators.email(' ana@example.com '), isNull);
  });

  test('password follows the API strength rules', () {
    expect(Validators.password(null), ValidationError.required);
    expect(Validators.password('Ab1'), ValidationError.passwordTooShort);
    expect(
      Validators.password('Ab1${'x' * 70}'),
      ValidationError.passwordTooLong,
    );
    expect(Validators.password('secret123'), ValidationError.weakPassword);
    expect(Validators.password('SECRET123'), ValidationError.weakPassword);
    expect(Validators.password('SecretPass'), ValidationError.weakPassword);
    expect(Validators.password('Secret123'), isNull);
  });

  test('matches compares with the other value', () {
    expect(Validators.matches('a', 'b'), ValidationError.mismatch);
    expect(Validators.matches('a', 'a'), isNull);
  });
}
