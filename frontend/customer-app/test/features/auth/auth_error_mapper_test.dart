import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/features/auth/data/mappers/auth_error_mapper.dart';
import 'package:caresitter_customer/features/auth/domain/google_identity_gateway.dart';
import 'package:caresitter_customer/features/auth/domain/auth_validators.dart';
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
    test('accepts email and Vietnamese phone login identifiers', () {
      expect(
        AuthValidators.loginEmail(''),
        'Vui lòng nhập email hoặc số điện thoại',
      );
      expect(
        AuthValidators.loginEmail('invalid'),
        'Email hoặc số điện thoại không hợp lệ',
      );
      expect(AuthValidators.loginEmail('user@example.com'), isNull);
      expect(AuthValidators.loginEmail('0901234567'), isNull);
      expect(AuthValidators.loginEmail('+84901234567'), isNull);
      expect(AuthValidators.loginEmail('+84 (90) 123-4567'), isNull);
      expect(AuthValidators.loginEmail('090123456'), isNotNull);

      expect(AuthValidators.loginPassword(''), 'Vui lòng nhập mật khẩu');
      expect(
        AuthValidators.loginPassword('12345'),
        'Mật khẩu tối thiểu 6 ký tự',
      );
      expect(AuthValidators.loginPassword('123456'), isNull);
    });
  });

  group('AuthErrorMapper.google', () {
    test('does not show an error when the user closes the Google chooser', () {
      const error = GoogleIdentityException(
        GoogleIdentityFailureCode.cancelled,
        'cancelled',
      );

      expect(AuthErrorMapper.google(error), isNull);
    });

    test('maps an OAuth configuration failure to an actionable message', () {
      const error = GoogleIdentityException(
        GoogleIdentityFailureCode.configuration,
        'missing client id',
      );

      expect(
        AuthErrorMapper.google(error),
        contains('chưa được cấu hình đúng'),
      );
    });

    test('maps a rejected backend ID token', () {
      const error = AppApiException(
        message: 'Google ID Token không hợp lệ hoặc đã hết hạn.',
        statusCode: 400,
        code: 'auth.invalid_google_token',
      );

      expect(
        AuthErrorMapper.google(error),
        'Phiên xác thực Google không hợp lệ hoặc đã hết hạn.',
      );
    });
  });
}
