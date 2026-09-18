import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/api/dio_client.dart';

final beneficiaryRepositoryProvider = Provider<BeneficiaryRepository>(
  (ref) => BeneficiaryRepository(ref.read(dioClientProvider)),
);

class BeneficiaryRepository {
  final DioClient _dio;

  const BeneficiaryRepository(this._dio);

  Future<List<Map<String, dynamic>>> getBeneficiaries() async {
    final response = await _dio.get<List<dynamic>>('/beneficiaries');
    return (response.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<Map<String, dynamic>?> createBeneficiary(
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/beneficiaries',
      data: data,
    );
    return response.data;
  }

  Future<void> updateBeneficiary(
    String id,
    Map<String, dynamic> data,
  ) async {
    await _dio.put<void>('/beneficiaries/$id', data: data);
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
