import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());

class AuthRepository {
  Future<void> requestOtp(String phone) async {
    await Future.delayed(const Duration(seconds: 1));
  }
}
