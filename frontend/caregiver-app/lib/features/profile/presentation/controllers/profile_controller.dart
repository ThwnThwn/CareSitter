import 'dart:io';
import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'package:caregiver_app/core/error/app_exception.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/features/profile/data/models/caregiver_profile_model.dart';
import 'package:caregiver_app/features/profile/data/repositories/profile_repository.dart';

final profileProvider =
    StateNotifierProvider<ProfileController, CaregiverProfileModel>((ref) {
  ref.watch(authStateProvider.select(
      (session) => (session.value?.userId, session.value?.isAuthenticated)));
  return ProfileController(ref);
});

/// True khi đang upload avatar — block double-tap.
final caregiverAvatarUploadingProvider = StateProvider<bool>((ref) {
  ref.watch(authStateProvider.select(
      (session) => (session.value?.userId, session.value?.isAuthenticated)));
  return false;
});

class ProfileController extends StateNotifier<CaregiverProfileModel> {
  final Ref _ref;
  int _refreshGeneration = 0;
  ApiCancellation? _kycCancellation;

  ProfileController(this._ref) : super(CaregiverProfileModel.empty()) {
    refresh();
  }

  ProfileRepository get _repository => _ref.read(profileRepositoryProvider);

  Future<void> refresh() async {
    if (!mounted) return;
    final generation = ++_refreshGeneration;
    final auth = _ref.read(authStateProvider).value;
    if (!(auth?.isAuthenticated ?? false)) {
      state = CaregiverProfileModel.empty();
      return;
    }

    try {
      final profile = await _repository.getOrCreateProfile(
        fallbackName: auth?.phone,
      );
      if (!mounted || generation != _refreshGeneration) return;
      state = profile;
    } catch (error) {
      // ignore: avoid_print
      print('[ProfileController] Lỗi tải hồ sơ caregiver: $error');
    }
  }

  Future<bool> updateProfile({
    String? fullName,
    String? bio,
    int? yearsOfExperience,
    List<String>? skills,
    String? serviceCity,
    String? serviceDistrict,
    String? gender,
    String? dateOfBirth,
  }) async {
    if (!mounted) return false;
    try {
      await _repository.updateProfile(
        fullName: fullName,
        bio: bio,
        yearsOfExperience: yearsOfExperience,
        skills: skills,
        serviceCity: serviceCity,
        serviceDistrict: serviceDistrict,
        gender: gender,
        dateOfBirth: dateOfBirth,
      );
      if (!mounted) return false;
      await refresh();
      return mounted;
    } catch (error) {
      // ignore: avoid_print
      print('[ProfileController] Lỗi cập nhật hồ sơ: $error');
      return false;
    }
  }

  Future<void> toggleAvailability() async {
    if (!mounted) return;
    try {
      await _repository.updateAvailability(
        state.isOnline ? 'OFFLINE' : 'ONLINE',
      );
      if (!mounted) return;
      await refresh();
    } catch (error) {
      // ignore: avoid_print
      print('[ProfileController] Lỗi cập nhật trạng thái: $error');
    }
  }

  Future<bool> uploadAvatar(File imageFile) async {
    if (!mounted) return false;
    if (_ref.read(caregiverAvatarUploadingProvider)) return false;
    _ref.read(caregiverAvatarUploadingProvider.notifier).state = true;

    try {
      final success = await _repository.uploadAvatar(imageFile);
      if (!mounted) return false;
      if (success) await refresh();
      return mounted && success;
    } catch (_) {
      return false;
    } finally {
      if (mounted) {
        _ref.read(caregiverAvatarUploadingProvider.notifier).state = false;
      }
    }
  }

  Future<void> submitKyc({
    required String cccdNumber,
    required File cccdFront,
    required File cccdBack,
    List<File> certificates = const [],
  }) async {
    if (!mounted) return;
    if (_kycCancellation != null) {
      throw const AppApiException(
          message: 'Hồ sơ đang được gửi. Vui lòng chờ.');
    }
    final cancellation = _kycCancellation = ApiCancellation();
    try {
      await _repository.submitKyc(
        cccdNumber: cccdNumber,
        cccdFront: cccdFront,
        cccdBack: cccdBack,
        certificates: List<File>.of(certificates),
        cancellation: cancellation,
      );
      if (!mounted) return;
      await refresh();
    } finally {
      if (mounted) _kycCancellation = null;
    }
  }

  @override
  void dispose() {
    _kycCancellation?.cancel();
    super.dispose();
  }
}
