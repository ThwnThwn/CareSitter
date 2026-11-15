import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/booking/data/models/caregiver_suggestion_model.dart';

void main() {
  test(
      'missing experience stays unknown and verified match reasons are preserved',
      () {
    final caregiver = CaregiverSuggestionModel.fromJson({
      'caregiverId': 'id',
      'displayName': 'Người chăm sóc',
      'yearsOfExperience': null,
      'availabilityStatus': 'OFFLINE',
      'ratingAverage': 0,
      'ratingCount': 0,
      'matchReasons': ['no_booking_conflict', 'service_area_match'],
    }).caregiver;
    expect(caregiver.yearsOfExperience, isNull);
    expect(caregiver.experienceLabel, contains('chưa cập nhật'));
    expect(caregiver.isOnline, isFalse);
    expect(
        caregiver.matchReasons, ['no_booking_conflict', 'service_area_match']);
  });
}
