import 'dart:async';
import 'package:caresitter_customer/app/router/app_router.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/features/auth/data/models/auth_models.dart';
import 'package:caresitter_customer/features/auth/data/services/google_sign_in_gateway.dart';
import 'package:caresitter_customer/features/auth/domain/google_identity_gateway.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/auth_session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'the production router leaves login after the first Google credential',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final gateway = _Google();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      googleIdentityGatewayProvider.overrideWithValue(gateway),
      authSessionControllerProvider.overrideWith((ref) => _Session(ref)),
    ]);
    addTearDown(container.dispose);
    addTearDown(gateway.close);
    await container.read(authStateProvider.future);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    router.go(AppRoutes.login);
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('google-sign-in-button'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(authStateProvider).value!.isAuthenticated, isTrue);
    expect(gateway.calls, 1);
    expect(
        router.routeInformationProvider.value.uri.path, AppRoutes.brandIntro);
    (container.read(authStateProvider.notifier) as _Auth)
        .rejectWithCachedError();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
    (container.read(authStateProvider.notifier) as _Auth).accept();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
        router.routeInformationProvider.value.uri.path, AppRoutes.brandIntro);
    (container.read(authStateProvider.notifier) as _Auth).reject();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
    await tester.pumpWidget(const SizedBox());
  });
}

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState.initial();
  void accept() => state = const AsyncData(AuthState(
      isAuthenticated: true,
      userId: 'fixture-owner',
      accessToken: 'fixture-access'));
  void reject() => state = const AsyncData(AuthState.initial());
  void rejectWithCachedError() => state = AsyncError<AuthState>(
          StateError('fixture restoration failed'), StackTrace.current)
      .copyWithPrevious(state);
}

class _Session extends AuthSessionController {
  _Session(super.ref);
  @override
  Future<AuthResponse> loginWithGoogleIdToken(String token) async {
    (ref.read(authStateProvider.notifier) as _Auth).accept();
    return const AuthResponse(
        accessToken: 'fixture-access',
        refreshToken: 'fixture-refresh',
        userId: 'fixture-owner',
        roles: ['CUSTOMER']);
  }
}

class _Google implements GoogleIdentityGateway {
  final _events = StreamController<GoogleIdentityCredential>.broadcast();
  int calls = 0;
  @override
  Stream<GoogleIdentityCredential> get credentials => _events.stream;
  @override
  Future<void> authenticate() async {
    calls++;
    _events
        .add(const GoogleIdentityCredential(idToken: 'fixture-google-token'));
  }

  @override
  Future<void> initialize() async {}
  @override
  Future<void> clearLocalSelection() async {}
  Future<void> close() => _events.close();
}
