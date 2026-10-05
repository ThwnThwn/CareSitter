import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:caregiver_app/features/auth/data/repositories/auth_repository.dart';
import 'package:caregiver_app/features/auth/presentation/screens/register_screen.dart';

class RecordingDioClient implements DioClient {
  String? path;
  Map<String, dynamic>? body;

  @override
  Future<Response<T>> post<T>(String path,
      {dynamic data, CancelToken? cancelToken}) async {
    this.path = path;
    body = data as Map<String, dynamic>;
    return Response<T>(
      data: <String, dynamic>{} as T,
      requestOptions: RequestOptions(path: path),
      statusCode: 201,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Registration form fits a small phone with larger text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: RegisterScreen(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Đăng ký Caregiver'), findsOneWidget);
    expect(find.text('Họ và tên'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Caregiver registration always sends the CAREGIVER role', () async {
    final client = RecordingDioClient();
    final container = ProviderContainer(overrides: [
      dioClientProvider.overrideWithValue(client),
    ]);
    addTearDown(container.dispose);

    await container.read(authRepositoryProvider).register(
          fullName: 'Nguyễn Minh Anh',
          email: 'CAREGIVER@example.com',
          phone: '0912345678',
          password: 'Password1',
          confirmPassword: 'Password1',
        );

    expect(client.path, '/auth/register');
    expect(client.body?['roles'], const ['CAREGIVER']);
    expect(client.body?['email'], 'caregiver@example.com');
  });
}
