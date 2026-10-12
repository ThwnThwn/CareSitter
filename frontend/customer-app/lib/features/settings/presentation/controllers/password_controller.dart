import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository.dart';

final passwordControllerProvider =
    Provider((ref) => PasswordController(ref.read(settingsRepositoryProvider)));

class PasswordController {
  const PasswordController(this._repository);
  final SettingsRepository _repository;
  Future<bool> changePassword(
          {required String currentPassword, required String newPassword}) =>
      _repository.changePassword(
          currentPassword: currentPassword, newPassword: newPassword);
}
