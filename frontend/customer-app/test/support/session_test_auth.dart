import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionTestAuth extends AuthNotifier {
  int _generation = 0;
  @override
  int get sessionGeneration => _generation;
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'first', isAuthenticated: true);
  void switchTo(String? id) {
    _generation++;
    state = AsyncData(AuthState(userId: id, isAuthenticated: id != null));
  }
}

Future<void> flushSessionWork() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
