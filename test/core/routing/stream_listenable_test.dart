import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/routing/stream_listenable.dart';

void main() {
  test('notifies listeners on every stream event until disposed', () async {
    final controller = StreamController<int>.broadcast();
    final listenable = StreamListenable(controller.stream);
    var notifications = 0;
    listenable.addListener(() => notifications++);

    controller
      ..add(1)
      ..add(2);
    await Future<void>.delayed(Duration.zero);
    listenable.dispose();
    controller.add(3);
    await Future<void>.delayed(Duration.zero);

    expect(notifications, 2);
    expect(controller.hasListener, isFalse);
    await controller.close();
  });
}
