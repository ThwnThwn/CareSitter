import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/features/settings/data/models/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.read(dioClientProvider)),
);

class ProfileRepository {
  final DioClient _dio;

  const ProfileRepository(this._dio);

  Future<UserProfile?> getProfile(UserProfile current) async {
    final response = await _dio.get<Map<String, dynamic>>('/profile');
    final data = response.data;
    if (data == null) return null;

    final fullName = _str(data['fullName'] ?? data['FullName']) ?? '';
    final displayName =
        _str(data['displayName'] ?? data['DisplayName']) ?? fullName;

    return UserProfile(
      name: fullName.isNotEmpty ? fullName : current.name,
      displayName: displayName.isNotEmpty ? displayName : current.displayName,
      phone: _str(data['phone'] ?? data['Phone']) ?? current.phone,
      email: _str(data['email'] ?? data['Email']) ?? current.email,
      gender: _str(data['gender'] ?? data['Gender']) ?? current.gender,
      dob: _str(data['dateOfBirth'] ?? data['DateOfBirth']) ?? current.dob,
      avatarUrl: _str(data['avatarUrl'] ?? data['AvatarUrl']),
      defaultAddressId:
          _str(data['defaultAddressId'] ?? data['DefaultAddressId']),
    );
  }

  Future<bool> updateProfile({
    required UserProfile current,
    String? name,
    String? displayName,
    String? email,
    String? dob,
    String? gender,
  }) async {
    String? formattedDob;
    if (dob != null && dob.trim().isNotEmpty) {
      final parts = dob.trim().split('/');
      formattedDob = parts.length == 3
          ? '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}'
          : dob.trim();
    }

    final response = await _dio.put<void>('/profile', data: {
      'FullName': name ?? current.name,
      'Email': email ?? current.email,
      'DisplayName': displayName ?? current.displayName,
      'DateOfBirth': formattedDob,
      'Gender': _normalizeGender(gender),
    });
    return response.statusCode == 200;
  }

  Future<bool> uploadAvatar(Uint8List imageBytes, String fileName) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        imageBytes,
        filename: fileName,
        contentType: DioMediaType('image', _mimeSubtype(fileName)),
      ),
    });
    final response = await _dio.postForm<Map<String, dynamic>>(
      '/profile/avatar',
      formData,
    );
    return response.statusCode == 200;
  }

  static String _mimeSubtype(String fileName) {
    return switch (fileName.split('.').last.toLowerCase()) {
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpeg',
    };
  }

  static String? _str(Object? value) {
    final normalized = value?.toString().trim();
    return (normalized == null || normalized.isEmpty) ? null : normalized;
  }

  static String? _normalizeGender(String? gender) {
    if (gender == null || gender.trim().isEmpty) return null;
    final normalized = gender.trim().toLowerCase();
    if (normalized == 'nam' || normalized == 'male') return 'MALE';
    if (normalized == 'nữ' || normalized == 'nu' || normalized == 'female') {
      return 'FEMALE';
    }
    if (normalized == 'khác' || normalized == 'khac' || normalized == 'other') {
      return 'OTHER';
    }
    return 'UNSPECIFIED';
  }
}
