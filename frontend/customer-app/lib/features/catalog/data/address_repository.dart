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
  final String? placeId;
  final String? provider;
  final DateTime? verifiedAt;
  final bool isVerified;
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
    this.placeId,
    this.provider,
    this.verifiedAt,
    this.isVerified = false,
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
        placeId: (json['placeId'] ?? json['PlaceId']) as String?,
        provider: (json['provider'] ?? json['Provider']) as String?,
        verifiedAt: DateTime.tryParse(
          (json['verifiedAt'] ?? json['VerifiedAt'])?.toString() ?? '',
        ),
        isVerified: (json['isVerified'] ?? json['IsVerified']) == true,
        note: (json['note'] ?? json['Note']) as String?,
      );
}

class PlaceSuggestionModel {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const PlaceSuggestionModel({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlaceSuggestionModel.fromJson(Map<String, dynamic> json) =>
      PlaceSuggestionModel(
        placeId: (json['placeId'] ?? json['PlaceId'])?.toString() ?? '',
        description:
            (json['description'] ?? json['Description'])?.toString() ?? '',
        mainText: (json['mainText'] ?? json['MainText'])?.toString() ?? '',
        secondaryText:
            (json['secondaryText'] ?? json['SecondaryText'])?.toString() ?? '',
      );
}

class VerifiedPlaceDetailsModel {
  final String placeId;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String? ward;
  final String? district;
  final String? city;
  final String country;

  const VerifiedPlaceDetailsModel({
    required this.placeId,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.ward,
    this.district,
    this.city,
    this.country = 'Vietnam',
  });

  factory VerifiedPlaceDetailsModel.fromJson(Map<String, dynamic> json) =>
      VerifiedPlaceDetailsModel(
        placeId: (json['placeId'] ?? json['PlaceId'])?.toString() ?? '',
        formattedAddress: (json['formattedAddress'] ?? json['FormattedAddress'])
                ?.toString() ??
            '',
        latitude: _readCoordinate(json, 'latitude', 'Latitude'),
        longitude: _readCoordinate(json, 'longitude', 'Longitude'),
        ward: (json['ward'] ?? json['Ward']) as String?,
        district: (json['district'] ?? json['District']) as String?,
        city: (json['city'] ?? json['City']) as String?,
        country: (json['country'] ?? json['Country'])?.toString() ?? 'Vietnam',
      );

  static double _readCoordinate(
    Map<String, dynamic> json,
    String camelCaseKey,
    String pascalCaseKey,
  ) {
    final value = json[camelCaseKey] ?? json[pascalCaseKey];
    if (value is num) return value.toDouble();
    throw const FormatException('Place details missing coordinates.');
  }
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
    required String placeId,
    String? sessionToken,
    String? label,
    String? note,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      ApiPaths.addresses,
      data: {
        'PlaceId': placeId,
        if (sessionToken != null && sessionToken.trim().isNotEmpty)
          'SessionToken': sessionToken.trim(),
        if (label != null && label.trim().isNotEmpty) 'Label': label.trim(),
        if (note != null && note.trim().isNotEmpty) 'Note': note.trim(),
      },
    );
    return AddressModel.fromJson(resp.data ?? const {});
  }

  Future<List<PlaceSuggestionModel>> autocompletePlaces({
    required String input,
    required String sessionToken,
  }) async {
    final resp = await _dio.get<List<dynamic>>(
      ApiPaths.addressAutocomplete,
      query: {
        'input': input,
        'sessionToken': sessionToken,
      },
    );
    final data = resp.data ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(PlaceSuggestionModel.fromJson)
        .where((item) => item.placeId.isNotEmpty)
        .toList();
  }

  Future<VerifiedPlaceDetailsModel> getPlaceDetails({
    required String placeId,
    required String sessionToken,
  }) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      ApiPaths.addressPlace(placeId),
      query: {'sessionToken': sessionToken},
    );
    return VerifiedPlaceDetailsModel.fromJson(resp.data ?? const {});
  }

  Future<void> deleteAddress(String id) async {
    await _dio.delete<void>(ApiPaths.addressById(id));
  }
}
