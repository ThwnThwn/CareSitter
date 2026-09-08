import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/auth/auth_notifier.dart';

class UserProfile {
  final String name;
  final String phone;
  final String email;
  final String dob;
  final String address;
  final String gender;
  final String language;
  final String? avatarPath;

  const UserProfile({
    required this.name,
    required this.phone,
    required this.email,
    required this.dob,
    required this.address,
    required this.gender,
    required this.language,
    this.avatarPath,
  });

  UserProfile copyWith({
    String? name,
    String? phone,
    String? email,
    String? dob,
    String? address,
    String? gender,
    String? language,
    String? avatarPath,
    bool clearAvatarPath = false,
  }) {
    return UserProfile(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      dob: dob ?? this.dob,
      address: address ?? this.address,
      gender: gender ?? this.gender,
      language: language ?? this.language,
      avatarPath: clearAvatarPath ? null : (avatarPath ?? this.avatarPath),
    );
  }
}

final profileStoreProvider =
    StateNotifierProvider<ProfileStore, UserProfile>((ref) {
  final store = ProfileStore(ref);
  // Tự động tải thông tin hồ sơ của tài khoản đang đăng nhập
  store.fetchProfile();
  return store;
});

class ProfileStore extends StateNotifier<UserProfile> {
  final Ref _ref;

  ProfileStore(this._ref)
      : super(_initialProfile()) {
    // Lắng nghe authState để tự động fetch khi đăng nhập hoặc reset khi đăng xuất
    _ref.listen(authStateProvider, (prev, next) {
      final isAuth = next.value?.isAuthenticated ?? false;
      if (isAuth) {
        fetchProfile();
      } else {
        reset();
      }
    });
  }

  static UserProfile _initialProfile() {
    return const UserProfile(
      name: '',
      phone: '',
      email: '',
      dob: '',
      address: '',
      gender: '',
      language: 'Tiếng Việt',
      avatarPath: null,
    );
  }

  /// Cập nhật nhanh tên và thông tin từ kết quả Auth
  void setFromAuth({String? name, String? phone, String? email}) {
    state = state.copyWith(
      name: (name != null && name.trim().isNotEmpty) ? name.trim() : null,
      phone: (phone != null && phone.trim().isNotEmpty) ? phone.trim() : null,
      email: (email != null && email.trim().isNotEmpty) ? email.trim() : null,
    );
  }

  /// Gọi API GET /profile để đồng bộ hồ sơ thật từ database
  Future<void> fetchProfile() async {
    final isAuth = _ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuth) return;

    try {
      final dio = _ref.read(dioClientProvider);
      final resp = await dio.get<Map<String, dynamic>>('/profile');
      if (resp.data != null) {
        final data = resp.data!;
        final fullName =
            (data['fullName'] ?? data['displayName'] ?? data['name']) as String?;
        final phone = (data['phone'] ?? data['Phone']) as String?;
        final email = (data['email'] ?? data['Email']) as String?;
        final gender = (data['gender'] ?? data['Gender']) as String?;
        final dob = (data['dateOfBirth'] ?? data['DateOfBirth'])?.toString();

        state = state.copyWith(
          name: (fullName != null && fullName.trim().isNotEmpty)
              ? fullName.trim()
              : state.name,
          phone: (phone != null && phone.trim().isNotEmpty)
              ? phone.trim()
              : state.phone,
          email: (email != null && email.trim().isNotEmpty)
              ? email.trim()
              : state.email,
          gender: (gender != null && gender.trim().isNotEmpty)
              ? gender.trim()
              : state.gender,
          dob: (dob != null && dob.trim().isNotEmpty) ? dob.trim() : state.dob,
        );
      }
    } catch (_) {
      // Bỏ qua lỗi mạng / server khi chưa load được profile
    }
  }

  void reset() {
    state = _initialProfile();
  }

  Future<bool> updateProfile({
    String? name,
    String? email,
    String? dob,
    String? address,
    String? gender,
    String? language,
    String? avatarPath,
  }) async {
    state = state.copyWith(
      name: name,
      email: email,
      dob: dob,
      address: address,
      gender: gender,
      language: language,
      avatarPath: avatarPath,
    );

    final isAuth = _ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuth) return true;

    try {
      final dio = _ref.read(dioClientProvider);
      String? formattedDob;
      if (dob != null && dob.trim().isNotEmpty) {
        final parts = dob.trim().split('/');
        if (parts.length == 3) {
          formattedDob = '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
        } else {
          formattedDob = dob.trim();
        }
      }

      String? normalizedGender;
      if (gender != null && gender.trim().isNotEmpty) {
        final g = gender.trim().toLowerCase();
        if (g == 'nam' || g == 'male') {
          normalizedGender = 'MALE';
        } else if (g == 'nữ' || g == 'female') {
          normalizedGender = 'FEMALE';
        } else {
          normalizedGender = 'OTHER';
        }
      }

      final payload = {
        'FullName': name ?? state.name,
        'Email': email ?? state.email,
        'DisplayName': name ?? state.name,
        'DateOfBirth': formattedDob,
        'Gender': normalizedGender,
      };

      final resp = await dio.put('/profile', data: payload);
      if (resp.statusCode == 200) {
        await fetchProfile();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

