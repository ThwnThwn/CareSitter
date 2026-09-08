import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/api/api_constants.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

/// Dia chi cua customer, anh xa tu AddressResponse cua BE.
class AddressModel {
  final String id;
  final String fullAddress;
  final String? label;
  final String? ward;
  final String? district;
  final String? city;
  final double? latitude;
  final double? longitude;
  final String? note;

  const AddressModel({
    required this.id,
    required this.fullAddress,
    this.label,
    this.ward,
    this.district,
    this.city,
    this.latitude,
    this.longitude,
    this.note,
  });

  /// Ten hien thi ngan gon: dung label neu co, fallback ve district/city.
  String get displayLabel {
    if (label != null && label!.isNotEmpty) return label!;
    final parts = [district, city].where((s) => s != null && s.isNotEmpty);
    if (parts.isNotEmpty) return parts.join(', ');
    return fullAddress;
  }

  /// Dia chi rut gon de hien thi trong chip.
  String get shortAddress {
    if (fullAddress.length <= 42) return fullAddress;
    return '${fullAddress.substring(0, 40)}...';
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) => AddressModel(
        id: (json['id'] ?? json['Id'])?.toString() ?? '',
        fullAddress:
            (json['fullAddress'] ?? json['FullAddress']) as String? ?? '',
        label: (json['label'] ?? json['Label']) as String?,
        ward: (json['ward'] ?? json['Ward']) as String?,
        district: (json['district'] ?? json['District']) as String?,
        city: (json['city'] ?? json['City']) as String?,
        latitude: (json['latitude'] as num?)?.toDouble() ??
            (json['Latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble() ??
            (json['Longitude'] as num?)?.toDouble(),
        note: (json['note'] ?? json['Note']) as String?,
      );
}

// ── Repository ────────────────────────────────────────────────────────────────

final addressRepositoryProvider = Provider<AddressRepository>(
  (ref) => AddressRepository(ref.read(dioClientProvider)),
);

/// Repository goi API quan ly dia chi cua customer.
class AddressRepository {
  final DioClient _dio;
  const AddressRepository(this._dio);

  /// Lay toan bo dia chi da luu cua user hien tai.
  Future<List<AddressModel>> getAddresses() async {
    final resp = await _dio.get<List<dynamic>>(ApiPaths.addresses);
    final data = resp.data ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AddressModel.fromJson)
        .toList();
  }

  Future<AddressModel> createAddress({
    required String fullAddress,
    required double latitude,
    required double longitude,
    String? label,
    String? ward,
    String? district,
    String? city,
    String? note,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      ApiPaths.addresses,
      data: {
        'FullAddress': fullAddress,
        'Latitude': latitude,
        'Longitude': longitude,
        if (label != null && label.trim().isNotEmpty) 'Label': label.trim(),
        if (ward != null && ward.trim().isNotEmpty) 'Ward': ward.trim(),
        if (district != null && district.trim().isNotEmpty)
          'District': district.trim(),
        if (city != null && city.trim().isNotEmpty) 'City': city.trim(),
        if (note != null && note.trim().isNotEmpty) 'Note': note.trim(),
      },
    );
    return AddressModel.fromJson(resp.data ?? const {});
  }

  Future<void> deleteAddress(String id) async {
    await _dio.delete<void>(ApiPaths.addressById(id));
  }
}
