abstract interface class GoogleAuthGateway {
  bool get enabled;

  bool get rendersOwnButton;

  Stream<String> get idTokens;

  Future<void> signIn();
}
