import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';

class VerifiedAddressSelection {
  final PlaceSuggestionModel suggestion;
  final VerifiedPlaceDetailsModel details;
  final String sessionToken;

  const VerifiedAddressSelection({
    required this.suggestion,
    required this.details,
    required this.sessionToken,
  });
}
