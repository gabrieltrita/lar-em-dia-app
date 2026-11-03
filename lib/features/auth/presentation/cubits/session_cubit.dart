import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/session/session_events.dart';
import 'package:lar_em_dia/features/auth/domain/auth_repository.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';

part 'session_cubit.freezed.dart';

@freezed
sealed class SessionState with _$SessionState {
  const factory unknown() = SessionUnknown;
  const factory authenticated(AuthUser user) = SessionAuthenticated;
  const factory unauthenticated() = SessionUnauthenticated;
}

@lazySingleton
class SessionCubit extends Cubit<SessionState> {
  new(this._repository, SessionEvents events)
    : super(const SessionState.unknown()) {
    _expired = events.expired.listen(
      (_) => emit(const SessionState.unauthenticated()),
    );
  }

  final AuthRepository _repository;
  late final StreamSubscription<void> _expired;

  Future<void> restore() async {
    final user = await _repository.restoreSession();
    emit(
      user == null
          ? const SessionState.unauthenticated()
          : SessionState.authenticated(user),
    );
  }

  void signedIn(AuthUser user) => emit(SessionState.authenticated(user));

  Future<void> logout() async {
    await _repository.logout();
    emit(const SessionState.unauthenticated());
  }

  @override
  Future<void> close() async {
    await _expired.cancel();
    await super.close();
  }
}
