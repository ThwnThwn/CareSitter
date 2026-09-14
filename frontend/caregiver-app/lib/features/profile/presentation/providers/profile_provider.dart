import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_constants.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/auth/auth_notifier.dart';
import '../../data/caregiver_profile_model.dart';

final profileProvider =
    StateNotifierProvider<ProfileNotifier, CaregiverProfileModel>((ref) {
  return ProfileNotifier(ref);
});

/// True khi đang upload avatar — block double-tap.
final caregiverAvatarUploadingProvider = StateProvider<bool>((_) => false);

class ProfileNotifier extends StateNotifier<CaregiverProfileModel> {
  final Ref _ref;

  ProfileNotifier(this._ref) : super(CaregiverProfileModel.empty()) {
    _ref.listen(authStateProvider, (previous, next) {
      final isAuth = next.value?.isAuthenticated ?? false;
      if (isAuth &&
          previous?.value?.isAuthenticated == true &&
          previous?.value?.userId == next.value?.userId) {
        return;
      }
      if (isAuth) {
        refresh();
      } else {
        state = CaregiverProfileModel.empty();
      }
    });
    refresh();
  }

  DioClient get _dio => _ref.read(dioClientProvider);

  /// GET /api/v1/caregivers/me/profile — server is source of truth.
  Future<void> refresh() async {
    final auth = _ref.read(authStateProvider).value;
    if (!(auth?.isAuthenticated ?? false)) {
      state = CaregiverProfileModel.empty();
      return;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.myCaregiverProfile,
      );
      if (response.data != null) {
        state = CaregiverProfileModel.fromJson(response.data!);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        try {
          final created = await _dio.post<Map<String, dynamic>>(
            ApiPaths.myCaregiverProfile,
            data: {'fullName': auth?.phone},
          );
          if (created.data != null) {
            state = CaregiverProfileModel.fromJson(created.data!);
          }
          return;
        } catch (_) {
          // Fall through to the diagnostic log below.
        }
      }
      // ignore: avoid_print
      print('[ProfileNotifier] Lỗi tải hồ sơ caregiver: $e');
    }
  }

  /// PUT /api/v1/caregivers/me/profile — server is source of truth.
  /// Không update state trước (tránh drift).
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
      await _dio.put<Map<String, dynamic>>(
        ApiPaths.myCaregiverProfile,
        data: {
          if (fullName != null) 'fullName': fullName,
          if (bio != null) 'bio': bio,
          if (yearsOfExperience != null) 'yearsOfExperience': yearsOfExperience,
          if (skills != null) 'skills': skills.join(','),
          if (serviceCity != null) 'serviceCity': serviceCity,
          if (serviceDistrict != null) 'serviceDistrict': serviceDistrict,
          if (gender != null) 'gender': gender,
          if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
        },
      );
      await refresh(); // server là source of truth
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('[ProfileNotifier] Lỗi cập nhật hồ sơ: $e');
      return false;
    }
  }

  /// PUT /api/v1/caregivers/me/status
  Future<void> toggleAvailability() async {
    final nextStatus = state.isOnline ? 'OFFLINE' : 'ONLINE';
    try {
      await _dio.put<Map<String, dynamic>>(
        ApiPaths.myCaregiverStatus,
        data: {'status': nextStatus},
      );
      await refresh();
    } catch (e) {
      // ignore: avoid_print
      print('[ProfileNotifier] Lỗi cập nhật trạng thái: $e');
    }
  }

  /// POST /profile/avatar (multipart) — chặn double-upload.
  Future<bool> uploadAvatar(File imageFile) async {
    if (_ref.read(caregiverAvatarUploadingProvider)) return false;
    _ref.read(caregiverAvatarUploadingProvider.notifier).state = true;

    try {
      final fileName = imageFile.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'file':
            await MultipartFile.fromFile(imageFile.path, filename: fileName),
      });
      final resp = await _dio.postForm<Map<String, dynamic>>(
        '/profile/avatar',
        formData,
      );
      if (resp.statusCode == 200) {
        await refresh(); // lấy avatarUrl mới
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _ref.read(caregiverAvatarUploadingProvider.notifier).state = false;
    }
  }

  Future<String> uploadKycImage(File imageFile) async {
    final fileName = imageFile.path.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(imageFile.path, filename: fileName),
      'folder': 'kyc',
    });
    final response = await _dio.postForm<Map<String, dynamic>>(
      '/media/upload',
      formData,
    );
    final url = response.data?['url']?.toString().trim();
    if (url == null || url.isEmpty) {
      throw const AppApiException(message: 'Máy chủ không trả về URL ảnh KYC.');
    }
    return url;
  }

  Future<void> submitKyc({
    required String cccdNumber,
    required File cccdFront,
    required File cccdBack,
    List<File> certificates = const [],
  }) async {
    final frontUrl = await uploadKycImage(cccdFront);
    final backUrl = await uploadKycImage(cccdBack);
    final certificateUrls = <String>[];
    for (final certificate in certificates) {
      certificateUrls.add(await uploadKycImage(certificate));
    }
    await _dio.post<Map<String, dynamic>>(
      '/caregivers/me/kyc',
      data: {
        'cccdNumber': cccdNumber.trim(),
        'cccdFrontUrl': frontUrl,
        'cccdBackUrl': backUrl,
        'certificateUrls': certificateUrls,
      },
    );
    await refresh();
  }
}
