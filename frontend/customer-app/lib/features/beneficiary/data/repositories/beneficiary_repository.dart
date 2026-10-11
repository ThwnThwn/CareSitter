import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/api/dio_client.dart';
import '../models/beneficiary_model.dart';

final beneficiaryRepositoryProvider = Provider<BeneficiaryRepository>(
  (ref) => BeneficiaryRepository(ref.read(dioClientProvider)),
);

class BeneficiaryRepository {
  final DioClient _dio;

  const BeneficiaryRepository(this._dio);

  static BeneficiaryModel _profile(Map<String, dynamic>? data) {
    final model = BeneficiaryModel.fromBackend(data ?? {});
    if (model.id.isEmpty) throw StateError('Máy chủ chưa trả về hồ sơ đã lưu.');
    return model;
  }

  Future<BeneficiaryModel> getBeneficiary(String id) async => _profile(
      (await _dio.get<Map<String, dynamic>>('/beneficiaries/$id')).data);

  Future<BeneficiaryModel?> getSelf() async {
    try {
      final value = _profile(
          (await _dio.get<Map<String, dynamic>>('/beneficiaries/self')).data);
      if (!value.isSelf) throw StateError('Hồ sơ bản thân chưa hợp lệ.');
      return value;
    } on DioException catch (e) {
      final error = e.error;
      if (e.response?.statusCode == 404 &&
          error is AppApiException &&
          error.code == 'beneficiary.self_not_found') {
        return null;
      }
      rethrow;
    }
  }

  Future<({BeneficiaryModel beneficiary, bool created})> createSelf(
      Map<String, dynamic> data) async {
    final response = await _dio
        .post<Map<String, dynamic>>('/beneficiaries/self', data: data);
    final value = _profile(response.data);
    if (!value.isSelf) throw StateError('Hồ sơ bản thân chưa hợp lệ.');
    return (beneficiary: value, created: response.statusCode == 201);
  }

  Future<BeneficiaryModel> linkSelf(String id) async {
    final response = await _dio.put<Map<String, dynamic>>(
        '/beneficiaries/self/link',
        data: {'beneficiaryId': id});
    final value = _profile(response.data);
    if (!value.isSelf || value.id != id) {
      throw StateError('Hồ sơ bản thân chưa hợp lệ.');
    }
    return value;
  }

  Future<List<Map<String, dynamic>>> getBeneficiaries() async {
    final response = await _dio.get<List<dynamic>>('/beneficiaries');
    return (response.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<Map<String, dynamic>> createBeneficiary(
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/beneficiaries',
      data: data,
    );
    return response.data ??
        (throw StateError('Máy chủ chưa trả về hồ sơ đã lưu.'));
  }

  Future<Map<String, dynamic>> updateBeneficiary(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response =
        await _dio.put<Map<String, dynamic>>('/beneficiaries/$id', data: data);
    return response.data ??
        (throw StateError('Máy chủ chưa trả về hồ sơ đã lưu.'));
  }

  Future<void> deleteBeneficiary(String id) async {
    await _dio.delete<void>('/beneficiaries/$id');
  }

  Future<String> uploadAvatar(Uint8List bytes, String fileName) async {
    final response = await _dio.postForm<Map<String, dynamic>>(
      '/media/upload',
      FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: DioMediaType('image', _mimeSubtype(fileName)),
        ),
        'folder': 'beneficiaries',
      }),
    );
    final url = response.data?['url']?.toString().trim();
    if (url == null || url.isEmpty) {
      throw StateError('Máy chủ không trả về URL ảnh người thân.');
    }
    return url;
  }

  static String _mimeSubtype(String fileName) {
    return switch (fileName.split('.').last.toLowerCase()) {
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpeg',
    };
  }
}
