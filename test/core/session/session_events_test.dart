import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/token_transport.dart';
import 'package:lar_em_dia/core/session/session_events.dart';

void main() {
  test('broadcasts expired sessions until disposed', () async {
    final events = SessionEvents();
    final received = <void>[];
    events.expired.listen(received.add);

    events.notifyExpired();
    await Future<void>.delayed(Duration.zero);
    await events.dispose();

    expect(received, hasLength(1));
  });

  test('uses the body transport outside the web', () {
    expect(TokenTransport.platform, same(TokenTransport.body));
    expect(TokenTransport.body.usesCookie, isFalse);
    expect(TokenTransport.cookie.usesCookie, isTrue);
  });
}
