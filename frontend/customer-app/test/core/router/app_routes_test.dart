import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public paths use canonical creation URLs', () {
    expect(AppRoutes.root, '/');
    expect(AppRoutes.bookingNew, '/bookings/new');
    expect(AppRoutes.beneficiaryNew, '/beneficiaries/new');
    expect(AppRoutes.nutritionKnowledge, '/nutrition/knowledge');
    expect(AppRoutes.bookingDetail('booking-1'), '/bookings/booking-1');
    expect(AppRoutes.serviceDetail('service-1'), '/catalog/service-1');
    expect(
        AppRoutes.beneficiaryEdit('person-1'), '/beneficiaries/person-1/edit');
  });

  test('IDs are encoded as one non-empty path segment', () {
    expect(AppRoutes.bookingDetail(' a/b '), '/bookings/a%2Fb');
    expect(() => AppRoutes.caregiverDetail('  '), throwsArgumentError);
    expect(AppRoutes.serviceDetail('service/a'), '/catalog/service%2Fa');
    expect(() => AppRoutes.beneficiaryDetail(''), throwsArgumentError);
  });

  test('booking creation query is encoded and uses kebab-case', () {
    final uri = Uri.parse(AppRoutes.bookingNewWith(
      serviceId: 'service/a',
      beneficiaryId: 'người thân',
    ));
    expect(uri.path, AppRoutes.bookingNew);
    expect(uri.queryParameters, {
      'service-id': 'service/a',
      'beneficiary-id': 'người thân',
    });
  });

  test('legacy booking link retains selections during redirect', () {
    final uri = Uri.parse(AppRoutes.bookingNewFromLegacy(Uri.parse(
      '/booking/new?serviceId=old&beneficiaryId=person-1&caregiverId=carer-1',
    )));
    expect(uri.path, AppRoutes.bookingNew);
    expect(uri.queryParameters, {
      'service-id': 'old',
      'beneficiary-id': 'person-1',
      'caregiver-id': 'carer-1',
    });
  });

  test('canonical query keys take precedence on legacy links', () {
    final uri = Uri.parse(AppRoutes.bookingNewFromLegacy(Uri.parse(
      '/booking/new?service-id=current&serviceId=old',
    )));
    expect(uri.queryParameters['service-id'], 'current');
    expect(uri.queryParameters.containsKey('serviceId'), isFalse);
  });
}
