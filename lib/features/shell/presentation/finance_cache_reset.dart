import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/cache/local_cache.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';

@lazySingleton
class FinanceCacheReset {
  new(this._session, this._cache);

  final SessionCubit _session;
  final LocalCache _cache;
  StreamSubscription<SessionState>? _subscription;
  String? _userId;

  void start() {
    _subscription ??= _session.stream.listen(_onSession);
    _onSession(_session.state);
  }

  void _onSession(SessionState state) {
    final userId = switch (state) {
      SessionAuthenticated(:final user) => user.id,
      _ => null,
    };
    if (userId != _userId) {
      _userId = userId;
      _cache.clear();
    }
  }

  @disposeMethod
  Future<void> dispose() async => await _subscription?.cancel();
}
