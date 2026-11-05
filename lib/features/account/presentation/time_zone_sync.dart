import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/features/account/domain/account_repository.dart';
import 'package:lar_em_dia/features/account/domain/device_time_zone.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';

@lazySingleton
class TimeZoneSync {
  new(this._session, this._repository, this._device);

  final SessionCubit _session;
  final AccountRepository _repository;
  final DeviceTimeZone _device;
  StreamSubscription<SessionState>? _subscription;
  String? _syncedUserId;

  void start() {
    _subscription ??= _session.stream.listen(
      (state) => unawaited(_onSession(state)),
    );
    unawaited(_onSession(_session.state));
  }

  Future<void> _onSession(SessionState state) async {
    if (state case SessionAuthenticated(:final user)) {
      if (user.id == _syncedUserId) {
        return;
      }
      _syncedUserId = user.id;
      await sync();
    } else {
      _syncedUserId = null;
    }
  }

  Future<void> sync() async {
    try {
      final device = await _device.current();
      if (await _repository.timeZone() != device) {
        await _repository.updateTimeZone(device);
      }
    } on Exception {
      return;
    }
  }

  @disposeMethod
  Future<void> dispose() async => await _subscription?.cancel();
}
