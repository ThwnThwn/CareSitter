import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/core/api/api_constants.dart';
import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:caregiver_app/core/error/app_exception.dart';
import 'package:caregiver_app/features/profile/data/models/caregiver_profile_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.read(dioClientProvider));
});

class ProfileRepository {
  final DioClient _dio;

  const ProfileRepository(this._dio);

  Future<CaregiverProfileModel> getOrCreateProfile({
    String? fallbackName,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.myCaregiverProfile,
      );
      return CaregiverProfileModel.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      if (error.response?.statusCode != 404) rethrow;
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.myCaregiverProfile,
        data: {'fullName': fallbackName},
      );
      return CaregiverProfileModel.fromJson(response.data ?? const {});
    }
  }

  Future<void> updateProfile({
    String? fullName,
    String? bio,
    int? yearsOfExperience,
    List<String>? skills,
    String? serviceCity,
    String? serviceDistrict,
    String? gender,
    String? dateOfBirth,
  }) {
    return _dio.put<Map<String, dynamic>>(
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
    ).then((_) {});
  }

  Future<void> updateAvailability(String status) {
    return _dio.put<Map<String, dynamic>>(
      ApiPaths.myCaregiverStatus,
      data: {'status': status},
    ).then((_) {});
  }

  Future<bool> uploadAvatar(File imageFile) async {
    final response = await _dio.postForm<Map<String, dynamic>>(
      '/profile/avatar',
      FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: _fileName(imageFile),
        ),
      }),
    );
    return response.statusCode == 200;
  }

  Future<String> uploadKycImage(File imageFile) async {
    final response = await _dio.postForm<Map<String, dynamic>>(
      '/media/upload',
      FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: _fileName(imageFile),
        ),
        'folder': 'kyc',
      }),
    );
    final url = response.data?['url']?.toString().trim();
    if (url == null || url.isEmpty) {
      throw const AppApiException(
        message: 'Máy chủ không trả về URL ảnh KYC.',
      );
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
  }

  static String _fileName(File file) =>
      file.path.split(Platform.pathSeparator).last;
}
