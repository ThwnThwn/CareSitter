import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/features/auth/data/mappers/auth_error_mapper.dart';
import 'package:caresitter_customer/features/auth/presentation/validators/auth_validators.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthErrorMapper.login', () {
    test('maps unauthorized responses to the existing credential message', () {
      const error = AppApiException(
        message: 'Unauthorized',
        statusCode: 401,
      );

      expect(
        AuthErrorMapper.login(error),
        'Email hoặc mật khẩu không đúng',
      );
    });

    test('maps not found responses to the existing account message', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/auth/login/password'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/auth/login/password'),
          statusCode: 404,
        ),
        error: const AppApiException(
          message: 'Not found',
          statusCode: 404,
        ),
      );

      expect(AuthErrorMapper.login(error), 'Tài khoản không tồn tại');
    });

    test('maps connection failures to the existing offline message', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/auth/login/password'),
        type: DioExceptionType.connectionError,
      );

      expect(AuthErrorMapper.login(error), 'Không có kết nối internet');
    });

    test('keeps a normalized API message when no special mapping applies', () {
      const error = AppApiException(
        message: 'Tài khoản đã bị khóa',
        statusCode: 423,
      );

      expect(AuthErrorMapper.login(error), 'Tài khoản đã bị khóa');
    });
  });

  group('AuthValidators', () {
    test('keeps the existing login validation rules', () {
      expect(AuthValidators.loginEmail(''), 'Vui lòng nhập email');
      expect(AuthValidators.loginEmail('invalid'), 'Email không hợp lệ');
      expect(AuthValidators.loginEmail('user@example.com'), isNull);

      expect(AuthValidators.loginPassword(''), 'Vui lòng nhập mật khẩu');
      expect(
        AuthValidators.loginPassword('12345'),
        'Mật khẩu tối thiểu 6 ký tự',
      );
      expect(AuthValidators.loginPassword('123456'), isNull);
    });
  });
}
