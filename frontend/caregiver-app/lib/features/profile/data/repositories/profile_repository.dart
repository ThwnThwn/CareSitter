import 'dart:convert';
import 'dart:io';
import 'package:caregiver_app/core/api/api_cancellation.dart';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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
    } on AppApiException catch (error) {
      if (error.statusCode != 404) rethrow;
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
        if (skills != null) 'skills': jsonEncode(skills),
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

  Future<bool> uploadAvatar(XFile imageFile) async {
    final length = await imageFile.length();
    if (length <= 0) {
      throw const AppApiException(message: 'File ảnh không được rỗng.');
    }
    if (length > 5 * 1024 * 1024) {
      throw const AppApiException(message: 'Ảnh không được vượt quá 5 MB.');
    }

    final pickedName = imageFile.name.trim().isEmpty
        ? ''
        : imageFile.name.split(RegExp(r'[/\\]')).last;
    final mime = _avatarMimeType(pickedName, imageFile.mimeType);
    final fileName = pickedName.isEmpty
        ? switch (mime) {
            'image/png' => 'avatar.png',
            'image/webp' => 'avatar.webp',
            _ => 'avatar.jpg',
          }
        : pickedName;
    final bytes = await imageFile.readAsBytes();
    final response = await _dio.postForm<Map<String, dynamic>>(
      '/profile/avatar',
      FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: DioMediaType.parse(mime),
        ),
      }),
    );
    return response.statusCode == 200;
  }

  static String _avatarMimeType(String fileName, String? providedMime) {
    const allowed = {'image/jpeg', 'image/png', 'image/webp'};
    final normalizedMime = providedMime?.trim().toLowerCase();
    if (normalizedMime != null && allowed.contains(normalizedMime)) {
      return normalizedMime;
    }

    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw const AppApiException(
          message: 'Chỉ nhận ảnh JPG, PNG hoặc WEBP.'),
    };
  }

  Future<String> uploadKycImage(File imageFile, String documentType,
      {ApiCancellation? cancellation}) async {
    final extension = _fileName(imageFile).split('.').last.toLowerCase();
    final mime = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw const AppApiException(
          message: 'Chỉ nhận ảnh JPG, PNG hoặc WEBP.'),
    };
    final response = await _dio.postForm<Map<String, dynamic>>(
      '/media/upload',
      FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: _fileName(imageFile),
          contentType: DioMediaType.parse(mime),
        ),
        'folder': 'kyc',
        'documentType': documentType,
      }),
      cancelToken: cancellation?.transportToken,
    );
    final mediaId = response.data?['mediaId']?.toString().trim();
    if (mediaId == null ||
        !RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
            .hasMatch(mediaId)) {
      throw const AppApiException(
        message:
            'Máy chủ không trả về mã tài liệu KYC an toàn. Không gửi URL ảnh thay thế.',
      );
    }
    return mediaId;
  }

  Future<void> submitKyc({
    required String cccdNumber,
    required File cccdFront,
    required File cccdBack,
    List<File> certificates = const [],
    ApiCancellation? cancellation,
  }) async {
    final frontId = await uploadKycImage(cccdFront, 'CCCD_FRONT',
        cancellation: cancellation);
    final backId =
        await uploadKycImage(cccdBack, 'CCCD_BACK', cancellation: cancellation);
    final certificateIds = <String>[];
    for (final certificate in certificates) {
      certificateIds.add(await uploadKycImage(certificate, 'OTHER',
          cancellation: cancellation));
    }
    await _dio.post<Map<String, dynamic>>(
      '/caregivers/me/kyc',
      data: {
        'cccdNumber': cccdNumber.trim(),
        'cccdFrontMediaId': frontId,
        'cccdBackMediaId': backId,
        'certificateMediaIds': certificateIds,
      },
      cancelToken: cancellation?.transportToken,
    );
  }

  static String _fileName(File file) =>
      file.path.split(Platform.pathSeparator).last;
}
