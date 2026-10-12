import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/features/settings/data/models/user_profile.dart';
import 'package:caresitter_customer/features/settings/data/repositories/profile_repository.dart';

export 'package:caresitter_customer/features/settings/data/models/user_profile.dart';

final profileStoreProvider =
    StateNotifierProvider<ProfileStore, UserProfile>((ref) {
  final store = ProfileStore(ref);
  store.fetchProfile();
  return store;
});

/// True khi đang upload avatar — block double-tap.
final avatarUploadingProvider = StateProvider<bool>((_) => false);

class ProfileStore extends StateNotifier<UserProfile> {
  final Ref _ref;
  int _uploadOperation = 0;
  bool _current(String? user, int generation) =>
      mounted &&
      _ref.read(authStateProvider).valueOrNull?.userId == user &&
      _ref.read(authStateProvider.notifier).sessionGeneration == generation;

  ProfileStore(this._ref) : super(_initialProfile()) {
    _ref.listen(authStateProvider, (previous, next) {
      if (previous?.valueOrNull?.userId != next.valueOrNull?.userId ||
          previous?.valueOrNull?.isAuthenticated !=
              next.valueOrNull?.isAuthenticated) {
        _uploadOperation++;
        _ref.read(avatarUploadingProvider.notifier).state = false;
      }
      final isAuthenticated = next.value?.isAuthenticated ?? false;
      if (isAuthenticated &&
          previous?.value?.isAuthenticated == true &&
          previous?.value?.userId == next.value?.userId) {
        return;
      }
      if (isAuthenticated) {
        fetchProfile();
      } else {
        reset();
      }
    });
  }

  ProfileRepository get _repository => _ref.read(profileRepositoryProvider);

  static UserProfile _initialProfile() => const UserProfile(
        name: '',
        displayName: '',
        phone: '',
        email: '',
        dob: '',
        gender: '',
        avatarUrl: null,
        defaultAddressId: null,
      );

  void setFromAuth({String? name, String? phone, String? email}) {
    state = state.copyWith(
      name: (name?.trim().isNotEmpty == true) ? name!.trim() : null,
      phone: (phone?.trim().isNotEmpty == true) ? phone!.trim() : null,
      email: (email?.trim().isNotEmpty == true) ? email!.trim() : null,
    );
  }

  Future<void> fetchProfile() async {
    final userId = _ref.read(authStateProvider).valueOrNull?.userId;
    final generation = _ref.read(authStateProvider.notifier).sessionGeneration;
    final isAuthenticated =
        _ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuthenticated) return;

    try {
      final profile = await _repository.getProfile(state);
      if (mounted &&
          profile != null &&
          _ref.read(authStateProvider).valueOrNull?.userId == userId &&
          _ref.read(authStateProvider.notifier).sessionGeneration ==
              generation) {
        state = profile;
      }
    } catch (_) {
      // Giữ state hiện tại khi backend tạm thời không truy cập được.
    }
  }

  void reset() {
    state = _initialProfile();
  }

  Future<bool> updateProfile({
    String? name,
    String? displayName,
    String? email,
    String? dob,
    String? gender,
  }) async {
    final user = _ref.read(authStateProvider).valueOrNull?.userId;
    final generation = _ref.read(authStateProvider.notifier).sessionGeneration;
    final isAuthenticated =
        _ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuthenticated) return false;

    try {
      final updated = await _repository.updateProfile(
        current: state,
        name: name,
        displayName: displayName,
        email: email,
        dob: dob,
        gender: gender,
      );
      if (!_current(user, generation)) return false;
      if (updated) await fetchProfile();
      return _current(user, generation) && updated;
    } catch (_) {
      return false;
    }
  }

  Future<bool> uploadAvatar(Uint8List imageBytes, String fileName) async {
    final user = _ref.read(authStateProvider).valueOrNull?.userId;
    final generation = _ref.read(authStateProvider.notifier).sessionGeneration;
    if (user == null) return false;
    if (_ref.read(avatarUploadingProvider)) return false;
    final operation = ++_uploadOperation;
    _ref.read(avatarUploadingProvider.notifier).state = true;

    try {
      final uploaded = await _repository.uploadAvatar(imageBytes, fileName);
      if (!_current(user, generation)) return false;
      if (uploaded) await fetchProfile();
      return _current(user, generation) && uploaded;
    } catch (_) {
      return false;
    } finally {
      if (mounted && operation == _uploadOperation) {
        _ref.read(avatarUploadingProvider.notifier).state = false;
      }
    }
  }
}
