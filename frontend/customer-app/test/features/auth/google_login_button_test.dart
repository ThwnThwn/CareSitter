import 'dart:async';

import 'package:caresitter_customer/features/auth/data/services/google_sign_in_gateway.dart';
import 'package:caresitter_customer/features/auth/domain/google_identity_gateway.dart';
import 'package:caresitter_customer/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Google button starts the platform account chooser',
      (tester) async {
    final googleIdentity = _FakeGoogleIdentityGateway();
    addTearDown(googleIdentity.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          googleIdentityGatewayProvider.overrideWithValue(googleIdentity),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('google-sign-in-button')),
    );
    await tester.tap(find.byKey(const ValueKey('google-sign-in-button')));
    await tester.pump();

    expect(googleIdentity.authenticateCalls, 1);
  });
}

class _FakeGoogleIdentityGateway implements GoogleIdentityGateway {
  final _credentials = StreamController<GoogleIdentityCredential>.broadcast();
  int authenticateCalls = 0;

  @override
  Stream<GoogleIdentityCredential> get credentials => _credentials.stream;

  @override
  Future<void> authenticate() async {
    authenticateCalls += 1;
  }

  @override
  Future<void> clearLocalSelection() async {}

  @override
  Future<void> initialize() async {}

  Future<void> dispose() => _credentials.close();
}
