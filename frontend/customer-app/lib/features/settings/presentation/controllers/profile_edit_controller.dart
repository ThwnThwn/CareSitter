import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'profile_controller.dart';
import 'profile_edit_state.dart';
import 'profile_save_result.dart';
export 'profile_edit_state.dart';
export 'profile_save_result.dart';

typedef ProfileUpdate = Future<bool> Function(
    {required String name,
    required String displayName,
    required String email,
    required String dob,
    required String gender});

final profileEditControllerProvider =
    StateNotifierProvider.autoDispose<ProfileEditController, ProfileEditState>(
        (ref) {
  ref.watch(authStateProvider
      .select((s) => (s.valueOrNull?.userId, s.valueOrNull?.isAuthenticated)));
  final store = ref.read(profileStoreProvider.notifier);
  return ProfileEditController(
      uploadAvatar: store.uploadAvatar, updateProfile: store.updateProfile);
});

class ProfileEditController extends StateNotifier<ProfileEditState> {
  ProfileEditController(
      {required this.uploadAvatar, required this.updateProfile})
      : super(const ProfileEditState());
  final Future<bool> Function(Uint8List, String) uploadAvatar;
  final ProfileUpdate updateProfile;
  Future<ProfileSaveResult> save(
      {required String name,
      required String displayName,
      required String email,
      required String dob,
      required String gender,
      XFile? avatar}) async {
    if (!mounted || state.busy) return const ProfileSaveResult(ignored: true);
    state = const ProfileEditState(busy: true);
    var avatarUploaded = false;
    String? warning;
    try {
      if (avatar != null) {
        final bytes = await avatar.readAsBytes();
        if (!mounted) return const ProfileSaveResult(ignored: true);
        avatarUploaded = await uploadAvatar(bytes, avatar.name);
        if (!mounted) return const ProfileSaveResult(ignored: true);
        if (!avatarUploaded) {
          warning = 'Upload ảnh thất bại. Ảnh đã chọn được giữ để thử lại.';
        }
      }
      final saved = await updateProfile(
          name: name.trim(),
          displayName: displayName.trim(),
          email: email.trim(),
          dob: dob.trim(),
          gender: gender);
      if (!mounted) return const ProfileSaveResult(ignored: true);
      final message = saved ? warning : 'Cập nhật thất bại. Vui lòng thử lại.';
      state = ProfileEditState(error: message);
      return ProfileSaveResult(
          saved: saved, avatarUploaded: avatarUploaded, message: message);
    } catch (_) {
      if (!mounted) return const ProfileSaveResult(ignored: true);
      const message = 'Cập nhật thất bại. Vui lòng thử lại.';
      state = const ProfileEditState(error: message);
      return ProfileSaveResult(
          avatarUploaded: avatarUploaded, message: message);
    }
  }
}
