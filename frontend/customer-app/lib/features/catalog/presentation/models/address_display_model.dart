import '../../data/models/address_model.dart';

extension AddressDisplay on AddressModel {
  String get displayLabel {
    if (label != null && label!.isNotEmpty) return label!;
    final parts = [district, city].where((s) => s != null && s.isNotEmpty);
    if (parts.isNotEmpty) return parts.join(', ');
    return fullAddress;
  }

  String get shortAddress {
    if (fullAddress.length <= 42) return fullAddress;
    return '${fullAddress.substring(0, 40)}...';
  }

}
