import 'package:caresitter_customer/features/auth/data/models/auth_models.dart';
import 'package:caresitter_customer/features/auth/data/services/google_sign_in_gateway.dart';
import 'package:caresitter_customer/features/auth/domain/google_identity_gateway.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/auth_session_controller.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/login_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes phone login while preserving email identifiers', () async {
    late _RecordingAuthSession session;
    final container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith((ref) {
          session = _RecordingAuthSession(ref);
          return session;
        }),
        googleIdentityGatewayProvider.overrideWithValue(
          _GoogleIdentityGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(loginControllerProvider.notifier);

    expect(
      await controller.login(
        email: '+84 (90) 123-4567',
        password: 'secret1',
      ),
      isTrue,
    );
    expect(session.lastRequest?.email, '0901234567');
    expect(session.lastRememberSession, isTrue);

    await controller.login(
      email: 'another@example.com',
      password: 'secret1',
      rememberSession: false,
    );
    expect(session.lastRememberSession, isFalse);

    expect(
      await controller.login(
        email: ' User@Example.com ',
        password: 'secret1',
      ),
      isTrue,
    );
    expect(session.lastRequest?.email, 'User@Example.com');
    expect(session.lastRememberSession, isTrue);
  });
}

class _RecordingAuthSession extends AuthSessionController {
  _RecordingAuthSession(super.ref);

  LoginRequest? lastRequest;
  bool? lastRememberSession;

  @override
  Future<AuthResponse> login(
    LoginRequest request, {
    bool rememberSession = true,
  }) async {
    lastRequest = request;
    lastRememberSession = rememberSession;
    return const AuthResponse(
      accessToken: 'access',
      refreshToken: 'refresh',
      userId: 'customer-id',
      roles: ['CUSTOMER'],
    );
  }
}

class _GoogleIdentityGateway implements GoogleIdentityGateway {
  @override
  Stream<GoogleIdentityCredential> get credentials => const Stream.empty();

  @override
  Future<void> authenticate() async {}

  @override
  Future<void> clearLocalSelection() async {}

  @override
  Future<void> initialize() async {}
}
