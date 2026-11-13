import 'package:flutter_test/flutter_test.dart';
import 'package:newwone/core/network/dio_client.dart';
import 'package:newwone/features/auth/data/datasources/auth_api_service.dart';
import 'package:newwone/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:newwone/features/auth/presentation/bloc/authentication_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AuthRepositoryImpl authRepo;
  late AuthenticationBloc bloc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dio = DioClient(baseUrl: 'demo');
    authRepo = AuthRepositoryImpl(
      apiService: AuthApiService(dio),
      dioClient: dio,
      preferences: prefs,
    );
    bloc = AuthenticationBloc(authRepository: authRepo);
  });

  tearDown(() => bloc.close());

  test('authenticates Rahul (EMP001) and persists session across restart',
      () async {
    bloc.add(
      const AuthLoginRequested(
        identifier: 'rahul@gmail.com',
        password: '123456',
      ),
    );

    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<AuthAuthenticated>()
            .having((s) => s.user.id, 'id', 'EMP001')
            .having((s) => s.user.isAdmin, 'isAdmin', isFalse),
      ),
    );

    final restored = await authRepo.restoreSession();
    expect(restored, isNotNull);
    expect(restored!.user.name, 'Rahul');
  });

  test('authenticates Admin (ADM001)', () async {
    bloc.add(
      const AuthLoginRequested(
        identifier: 'ADM001',
        password: 'admin123',
      ),
    );

    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<AuthAuthenticated>()
            .having((s) => s.user.id, 'id', 'ADM001')
            .having((s) => s.user.isAdmin, 'isAdmin', isTrue),
      ),
    );
  });

  test('emits AuthUnauthenticated with error message for wrong password',
      () async {
    bloc.add(
      const AuthLoginRequested(
        identifier: 'rahul@gmail.com',
        password: 'wrongpassword',
      ),
    );

    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<AuthUnauthenticated>()
            .having((s) => s.errorMessage, 'error', isNotNull),
      ),
    );
  });
}

