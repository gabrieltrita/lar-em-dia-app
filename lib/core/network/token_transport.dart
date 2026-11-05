import 'package:flutter/foundation.dart';

final class TokenTransport {
  const new({required this.usesCookie});

  static const body = TokenTransport(usesCookie: false);
  static const cookie = TokenTransport(usesCookie: true);
  static const header = 'X-Token-Transport';

  static TokenTransport get platform => kIsWeb ? cookie : body;

  final bool usesCookie;
}
