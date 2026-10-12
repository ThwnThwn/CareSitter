import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/recovery_repository.dart';
import '../../data/models/recovery_email_model.dart';
export '../../data/repositories/recovery_repository.dart'
    show RecoveryChallenge, RecoveryGrant, recoveryError;

final recoveryControllerProvider =
    Provider((ref) => RecoveryController(ref.read(recoveryRepositoryProvider)));

class RecoveryController {
  const RecoveryController(this._repository);
  final RecoveryRepository _repository;
  Future<RecoveryChallenge> request(String email) => _repository.request(email);
  Future<RecoveryGrant> verify(String id, String code) =>
      _repository.verify(id, code);
  Future<void> reset(String token, String password, String confirmation) =>
      _repository.reset(token, password, confirmation);
  Future<Map<String, dynamic>> profile() => _repository.profile();
  Future<RecoveryEmailModel> emailProfile() => _repository.emailProfile();
  Future<RecoveryEmailModel> confirmEmailProfile(String id, String code) =>
      _repository.confirmEmailProfile(id, code);
  Future<RecoveryChallenge> requestEmail(String email, String? password) =>
      _repository.requestEmail(email, password);
  Future<Map<String, dynamic>> confirmEmail(String id, String code) =>
      _repository.confirmEmail(id, code);
}
