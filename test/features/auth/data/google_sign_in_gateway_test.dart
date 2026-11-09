import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/auth/data/google_sign_in_gateway.dart';
import 'package:mocktail/mocktail.dart';

class MockGoogleSignIn extends Mock implements GoogleSignIn;

class MockGoogleAccount extends Mock implements GoogleSignInAccount;

void main() {
  late MockGoogleSignIn signIn;
  late StreamController<GoogleSignInAuthenticationEvent> events;

  setUp(() {
    signIn = MockGoogleSignIn();
    events = StreamController.broadcast();
    when(
      () => signIn.initialize(
        clientId: any(named: 'clientId'),
        serverClientId: any(named: 'serverClientId'),
      ),
    ).thenAnswer((_) async {});
    when(() => signIn.authenticationEvents).thenAnswer((_) => events.stream);
  });
  tearDown(() => events.close());

  GoogleSignInGateway build({String clientId = 'web-id', bool web = false}) =>
      GoogleSignInGateway(signIn, clientId: clientId, web: web);

  GoogleSignInAuthenticationEventSignIn signedIn(String? idToken) {
    final account = MockGoogleAccount();
    when(() => account.authentication)
        .thenReturn(GoogleSignInAuthentication(idToken: idToken));
    return GoogleSignInAuthenticationEventSignIn(user: account);
  }

  test('is enabled only with a client id', () {
    expect(build().enabled, isTrue);
    expect(build(clientId: '').enabled, isFalse);
  });

  test('renders its own button where it cannot authenticate', () {
    when(() => signIn.supportsAuthenticate()).thenReturn(false);
    expect(build().rendersOwnButton, isTrue);

    when(() => signIn.supportsAuthenticate()).thenReturn(true);
    expect(build().rendersOwnButton, isFalse);
  });

  test('uses the web client id as the server client id on mobile', () async {
    when(() => signIn.authenticate())
        .thenAnswer((_) async => MockGoogleAccount());
    final gateway = build();

    await gateway.signIn();
    await gateway.signIn();

    verify(() => signIn.initialize(serverClientId: 'web-id')).called(1);
    verify(() => signIn.authenticate()).called(2);
  });

  test('uses it as the client id on the web', () async {
    final gateway = build(web: true);
    final tokens = gateway.idTokens.listen((_) {});
    await pumpEventQueue();

    verify(() => signIn.initialize(clientId: 'web-id')).called(1);
    await tokens.cancel();
  });

  test('emits the ID token of each sign-in and skips the rest', () async {
    final tokens = <String>[];
    final subscription = build().idTokens.listen(tokens.add);
    await pumpEventQueue();

    events
      ..add(signedIn('token-1'))
      ..add(signedIn(null))
      ..add(GoogleSignInAuthenticationEventSignOut())
      ..addError(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.unknownError,
        ),
      )
      ..add(signedIn('token-2'));
    await pumpEventQueue();

    expect(tokens, ['token-1', 'token-2']);
    await subscription.cancel();
  });

  test('ignores a cancelled sign-in', () async {
    when(() => signIn.authenticate()).thenThrow(
      const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
    );

    await expectLater(build().signIn(), completes);
  });

  test('reports any other failure by code', () async {
    when(() => signIn.authenticate()).thenThrow(
      const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
      ),
    );

    await expectLater(
      build().signIn(),
      throwsA(const ApiError(code: GoogleSignInGateway.failedCode)),
    );
  });
}
