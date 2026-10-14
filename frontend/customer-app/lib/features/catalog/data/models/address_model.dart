/// Địa chỉ của customer, ánh xạ từ AddressResponse của backend.
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
