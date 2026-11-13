import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginFormState extends Equatable {
  const LoginFormState({
    this.obscurePassword = true,
  });

  final bool obscurePassword;

  LoginFormState copyWith({bool? obscurePassword}) {
    return LoginFormState(
      obscurePassword: obscurePassword ?? this.obscurePassword,
    );
  }

  @override
  List<Object?> get props => [obscurePassword];
}

/// Manages Login UI interactions (password visibility) without setState.
class LoginFormCubit extends Cubit<LoginFormState> {
  LoginFormCubit() : super(const LoginFormState());

  void togglePasswordVisibility() {
    emit(state.copyWith(obscurePassword: !state.obscurePassword));
  }
}

