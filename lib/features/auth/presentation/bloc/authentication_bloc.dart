import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:newwone/core/network/api_exception.dart';
import 'package:newwone/features/auth/domain/entities/user_entity.dart';
import 'package:newwone/features/auth/domain/repositories/auth_repository.dart';

// --- Events ---
abstract class AuthenticationEvent extends Equatable {
  const AuthenticationEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthenticationEvent {
  const AuthCheckRequested();
}

class AuthLoginRequested extends AuthenticationEvent {
  const AuthLoginRequested({
    required this.identifier,
    required this.password,
  });

  final String identifier;
  final String password;

  @override
  List<Object?> get props => [identifier, password];
}

class AuthLogoutRequested extends AuthenticationEvent {
  const AuthLogoutRequested();
}

class AuthSessionExpired extends AuthenticationEvent {
  const AuthSessionExpired(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

// --- States ---
abstract class AuthenticationState extends Equatable {
  const AuthenticationState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthenticationState {
  const AuthInitial();
}

class AuthSessionChecking extends AuthenticationState {
  const AuthSessionChecking();
}

class AuthAuthenticated extends AuthenticationState {
  const AuthAuthenticated({
    required this.user,
    required this.token,
    required this.isDemoMode,
  });

  final UserEntity user;
  final String token;
  final bool isDemoMode;

  @override
  List<Object?> get props => [user, token, isDemoMode];
}

class AuthUnauthenticated extends AuthenticationState {
  const AuthUnauthenticated({
    this.errorMessage,
    this.isLoading = false,
  });

  final String? errorMessage;
  final bool isLoading;

  @override
  List<Object?> get props => [errorMessage, isLoading];
}

// --- BLoC ---
class AuthenticationBloc
    extends Bloc<AuthenticationEvent, AuthenticationState> {
  AuthenticationBloc({
    required AuthRepository authRepository,
    Stream<ApiException>? unauthorizedStream,
  })  : _authRepository = authRepository,
        super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSessionExpired>(_onSessionExpired);

    if (unauthorizedStream != null) {
      _unauthorizedSubscription = unauthorizedStream.listen((err) {
        if (state is AuthAuthenticated) {
          add(AuthSessionExpired(err.message));
        }
      });
    }
  }

  final AuthRepository _authRepository;
  StreamSubscription<ApiException>? _unauthorizedSubscription;

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthenticationState> emit,
  ) async {
    emit(const AuthSessionChecking());
    // Restore SharedPreferences session in parallel with splash animation.
    final results = await Future.wait<dynamic>([
      _authRepository.restoreSession(),
      Future<void>.delayed(const Duration(milliseconds: 700)),
    ]);
    final session = results[0] as AuthSession?;
    if (session != null) {
      emit(
        AuthAuthenticated(
          user: session.user,
          token: session.token,
          isDemoMode: session.isDemoMode,
        ),
      );
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthenticationState> emit,
  ) async {
    emit(const AuthUnauthenticated(isLoading: true));
    try {
      final session = await _authRepository.login(
        identifier: event.identifier,
        password: event.password,
      );
      emit(
        AuthAuthenticated(
          user: session.user,
          token: session.token,
          isDemoMode: session.isDemoMode,
        ),
      );
    } on ApiException catch (e) {
      emit(AuthUnauthenticated(errorMessage: e.message));
    } catch (e) {
      emit(
        AuthUnauthenticated(
          errorMessage: 'Unable to sign in right now. (${e.toString()})',
        ),
      );
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthenticationState> emit,
  ) async {
    await _authRepository.logout();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onSessionExpired(
    AuthSessionExpired event,
    Emitter<AuthenticationState> emit,
  ) async {
    await _authRepository.logout();
    emit(AuthUnauthenticated(errorMessage: event.message));
  }

  @override
  Future<void> close() async {
    await _unauthorizedSubscription?.cancel();
    return super.close();
  }
}
