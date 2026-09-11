import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/auth/auth_notifier.dart';

class UserProfile {
  final String name;
  final String displayName;
  final String phone;
  final String email;
  final String dob;
  final String gender;
  /// URL ảnh đại diện từ Cloudinary (null → hiện initials).
  final String? avatarUrl;
  final String? defaultAddressId;

  const UserProfile({
    required this.name,
    required this.displayName,
    required this.phone,
    required this.email,
    required this.dob,
    required this.gender,
    this.avatarUrl,
    this.defaultAddressId,
  });

  UserProfile copyWith({
    String? name,
    String? displayName,
    String? phone,
    String? email,
    String? dob,
    String? gender,
    String? avatarUrl,
    bool clearAvatarUrl = false,
    String? defaultAddressId,
    bool clearDefaultAddressId = false,
  }) {
    return UserProfile(
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      defaultAddressId: clearDefaultAddressId
          ? null
          : (defaultAddressId ?? this.defaultAddressId),
    );
  }
}

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

  ProfileStore(this._ref) : super(_initialProfile()) {
    // Tự reload khi auth thay đổi
    _ref.listen(authStateProvider, (prev, next) {
      final isAuth = next.value?.isAuthenticated ?? false;
      if (isAuth) {
        fetchProfile();
      } else {
        reset();
      }
    });
  }

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

  /// Cập nhật nhanh từ auth response (sau khi login).
  void setFromAuth({String? name, String? phone, String? email}) {
    state = state.copyWith(
      name: (name?.trim().isNotEmpty == true) ? name!.trim() : null,
      phone: (phone?.trim().isNotEmpty == true) ? phone!.trim() : null,
      email: (email?.trim().isNotEmpty == true) ? email!.trim() : null,
    );
  }

  /// GET /profile — đồng bộ state từ server.
  /// Server là source of truth, không giữ optimistic state.
  Future<void> fetchProfile() async {
    final isAuth = _ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuth) return;

    try {
      final dio = _ref.read(dioClientProvider);
      final resp = await dio.get<Map<String, dynamic>>('/profile');
      final data = resp.data;
      if (data == null) return;

      final fullName = _str(data['fullName'] ?? data['FullName']) ?? '';
      final displayName =
          _str(data['displayName'] ?? data['DisplayName']) ?? fullName;

      state = UserProfile(
        name: fullName.isNotEmpty ? fullName : state.name,
        displayName: displayName.isNotEmpty ? displayName : state.displayName,
        phone: _str(data['phone'] ?? data['Phone']) ?? state.phone,
        email: _str(data['email'] ?? data['Email']) ?? state.email,
        gender: _str(data['gender'] ?? data['Gender']) ?? state.gender,
        dob: _str(data['dateOfBirth'] ?? data['DateOfBirth']) ?? state.dob,
        avatarUrl: _str(data['avatarUrl'] ?? data['AvatarUrl']),
        defaultAddressId:
            _str(data['defaultAddressId'] ?? data['DefaultAddressId']),
      );
    } catch (_) {
      // Lỗi mạng / server — giữ state cũ, không crash UI.
    }
  }

  void reset() {
    state = _initialProfile();
  }

  // ── PUT /profile ─────────────────────────────────────────────────────────────

  /// Gọi PUT /profile, chỉ update state SAU KHI server thành công.
  /// Không update state trước (tránh UI-DB drift khi API fail).
  Future<bool> updateProfile({
    String? name,
    String? displayName,
    String? email,
    String? dob,
    String? gender,
  }) async {
    final isAuth = _ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuth) return false;

    try {
      final dio = _ref.read(dioClientProvider);

      // DOB: dd/MM/yyyy → yyyy-MM-dd (backend DateOnly format)
      String? formattedDob;
      if (dob != null && dob.trim().isNotEmpty) {
        final parts = dob.trim().split('/');
        formattedDob = parts.length == 3
            ? '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}'
            : dob.trim();
      }

      // Gender display → enum
      final normalizedGender = _normalizeGender(gender);

      final resp = await dio.put('/profile', data: {
        'FullName': name ?? state.name,
        'Email': email ?? state.email,
        'DisplayName': displayName ?? state.displayName,
        'DateOfBirth': formattedDob,
        'Gender': normalizedGender,
      });

      if (resp.statusCode == 200) {
        await fetchProfile(); // server is source of truth
        return true;
      }
      return false;
    } catch (_) {
      // API failed → state không thay đổi (không drift)
      return false;
    }
  }

  // ── POST /profile/avatar ─────────────────────────────────────────────────────

  /// Upload ảnh đại diện lên Cloudinary qua backend.
  /// Chặn double-upload bằng [avatarUploadingProvider].
  Future<bool> uploadAvatar(File imageFile) async {
    if (_ref.read(avatarUploadingProvider)) return false;
    _ref.read(avatarUploadingProvider.notifier).state = true;

    try {
      final dio = _ref.read(dioClientProvider);
      final fileName = imageFile.path.split(Platform.pathSeparator).last;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final resp = await dio.postForm<Map<String, dynamic>>(
        '/profile/avatar',
        formData,
      );

      if (resp.statusCode == 200) {
        await fetchProfile(); // lấy avatarUrl mới
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _ref.read(avatarUploadingProvider.notifier).state = false;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String? _str(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static String? _normalizeGender(String? gender) {
    if (gender == null || gender.trim().isEmpty) return null;
    final g = gender.trim().toLowerCase();
    if (g == 'nam' || g == 'male') return 'MALE';
    if (g == 'nữ' || g == 'nu' || g == 'female') return 'FEMALE';
    if (g == 'khác' || g == 'khac' || g == 'other') return 'OTHER';
    return 'UNSPECIFIED';
  }
}
