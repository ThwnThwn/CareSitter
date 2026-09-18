import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/features/profile/data/models/caregiver_profile_model.dart';
import 'package:caregiver_app/features/profile/data/repositories/profile_repository.dart';

final profileProvider =
    StateNotifierProvider<ProfileController, CaregiverProfileModel>((ref) {
  return ProfileController(ref);
});

/// True khi đang upload avatar — block double-tap.
final caregiverAvatarUploadingProvider = StateProvider<bool>((_) => false);

class ProfileController extends StateNotifier<CaregiverProfileModel> {
  final Ref _ref;

  ProfileController(this._ref) : super(CaregiverProfileModel.empty()) {
    _ref.listen(authStateProvider, (previous, next) {
      final isAuthenticated = next.value?.isAuthenticated ?? false;
      if (isAuthenticated &&
          previous?.value?.isAuthenticated == true &&
          previous?.value?.userId == next.value?.userId) {
        return;
      }
      if (isAuthenticated) {
        refresh();
      } else {
        state = CaregiverProfileModel.empty();
      }
    });
    refresh();
  }

  ProfileRepository get _repository => _ref.read(profileRepositoryProvider);

  Future<void> refresh() async {
    final auth = _ref.read(authStateProvider).value;
    if (!(auth?.isAuthenticated ?? false)) {
      state = CaregiverProfileModel.empty();
      return;
    }

    try {
      state = await _repository.getOrCreateProfile(
        fallbackName: auth?.phone,
      );
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
      await refresh();
      return true;
    } catch (error) {
      // ignore: avoid_print
      print('[ProfileController] Lỗi cập nhật hồ sơ: $error');
      return false;
    }
  }

  Future<void> toggleAvailability() async {
    try {
      await _repository.updateAvailability(
        state.isOnline ? 'OFFLINE' : 'ONLINE',
      );
      await refresh();
    } catch (error) {
      // ignore: avoid_print
      print('[ProfileController] Lỗi cập nhật trạng thái: $error');
    }
  }

  Future<bool> uploadAvatar(File imageFile) async {
    if (_ref.read(caregiverAvatarUploadingProvider)) return false;
    _ref.read(caregiverAvatarUploadingProvider.notifier).state = true;

    try {
      final success = await _repository.uploadAvatar(imageFile);
      if (success) await refresh();
      return success;
    } catch (_) {
      return false;
    } finally {
      _ref.read(caregiverAvatarUploadingProvider.notifier).state = false;
    }
  }

  Future<void> submitKyc({
    required String cccdNumber,
    required File cccdFront,
    required File cccdBack,
    List<File> certificates = const [],
  }) async {
    await _repository.submitKyc(
      cccdNumber: cccdNumber,
      cccdFront: cccdFront,
      cccdBack: cccdBack,
      certificates: certificates,
    );
    await refresh();
  }
}
