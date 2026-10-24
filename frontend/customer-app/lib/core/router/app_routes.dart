/// Public route paths and builders for the customer app.
///
/// Builders encode IDs as individual path segments and create query strings via
/// [Uri] so callers do not need to hand-assemble URL syntax.
class AppRoutes {
  AppRoutes._();

  static const root = '/';
  static const auth = '/auth';
  static const home = '/home';
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const email = '/auth/email';
  static const otp = '/auth/otp';
  static const forgotPassword = '/auth/forgot-password';
  static const brandIntro = '/brand-intro';
  static const bookings = '/bookings';
  static const bookingNew = '/bookings/new';
  static const legacyBookingNew = '/booking/new';
  static const nutrition = '/nutrition';
  static const caregivers = '/caregivers';
  static const beneficiaries = '/beneficiaries';
  static const beneficiaryNew = '/beneficiaries/new';
  static const legacyBeneficiaryCreate = '/beneficiaries/create';
  static const legacyAuthPhone = '/auth/phone';
  static const tracking = '/tracking';
  static const settings = '/settings';
  static const catalog = '/catalog';
  static const notifications = '/notifications';
  static const paymentResult = '/payment-result';
  static const wallet = '/wallet';
  static const recoveryEmail = '/settings/recovery-email';
  static const profileEdit = '/settings/profile/edit';
  static const addresses = '/settings/addresses';
  static const password = '/settings/password';
  static const notificationSettings = '/settings/notifications';
  static const faq = '/settings/faq';
  static const refunds = '/settings/refunds';
  static const support = '/settings/support';
  static const supportChat = '/settings/support/chat';

  static String bookingDetail(String id) => '$bookings/${_segment(id)}';
  static String serviceDetail(String id) => '$catalog/${_segment(id)}';
  static String bookingTracking(String id) => '${bookingDetail(id)}/tracking';
  static String bookingTimeline(String id) => '${bookingDetail(id)}/timeline';
  static String bookingReview(String id) => '${bookingDetail(id)}/review';
  static String bookingChat(String id, {String? title}) => _withQuery(
        '${bookingDetail(id)}/chat',
        {'title': title},
      );
  static String bookingDispute(String id) => '${bookingDetail(id)}/dispute';
  static String bookingNewWith({
    String? serviceId,
    String? beneficiaryId,
    String? caregiverId,
  }) =>
      _withQuery(bookingNew, {
        'service-id': serviceId,
        'beneficiary-id': beneficiaryId,
        'caregiver-id': caregiverId,
      });
  static String bookingNewFromLegacy(Uri uri) => bookingNewWith(
        serviceId: uri.queryParameters['service-id'] ??
            uri.queryParameters['serviceId'],
        beneficiaryId: uri.queryParameters['beneficiary-id'] ??
            uri.queryParameters['beneficiaryId'],
        caregiverId: uri.queryParameters['caregiver-id'] ??
            uri.queryParameters['caregiverId'],
      );
  static String bookingDetailPaymentResult({
    String? bookingId,
    String? intentId,
    String result = 'failed',
  }) =>
      _withQuery(paymentResult, {
        'booking-id': bookingId,
        'intent-id': intentId,
        'result': result,
      });
  static String caregiversSearch({String? query}) =>
      _withQuery(caregivers, {'q': query});
  static String caregiverDetail(String id) => '$caregivers/${_segment(id)}';
  static String beneficiaryDetail(String id) =>
      '$beneficiaries/${_segment(id)}';
  static String beneficiaryEdit(String id) => '${beneficiaryDetail(id)}/edit';
  static String beneficiaryNutrition(String id) =>
      '${beneficiaryDetail(id)}/nutrition';
  static String addressesSelect({String? selectedId}) => _withQuery(addresses, {
        'select': '1',
        'selected-id': selectedId,
      });

  static String _segment(String value) {
    final id = value.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(value, 'id', 'Route ID must not be blank');
    }
    return Uri.encodeComponent(id);
  }

  static String _withQuery(String path, Map<String, String?> values) {
    final query = <String, String>{
      for (final entry in values.entries)
        if (entry.value != null && entry.value!.isNotEmpty)
          entry.key: entry.value!,
    };
    return Uri(path: path, queryParameters: query.isEmpty ? null : query)
        .toString();
  }
}
