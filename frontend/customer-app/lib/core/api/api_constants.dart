/// API endpoint path constants cho CareSitter.
///
/// Sử dụng --dart-define=BASE_URL=http://localhost:5033/api/v1 khi chạy local.
/// Mặc định trỏ về production nếu không truyền biến.
library;

const String kBaseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'http://localhost:5033/api/v1',
);

class ApiPaths {
  ApiPaths._();

  // ── Bookings ──────────────────────────────────────────────
  static const bookings = '/bookings';
  static String booking(String id) => '/bookings/$id';
  static String bookingCancel(String id) => '/bookings/$id/cancel';

  // ── Booking lifecycle ──────────────────────────────────────
  static String confirmPayment(String id) => '/bookings/$id/confirm-payment';
  static String enRoute(String id) => '/bookings/$id/en-route';
  static String checkIn(String id) => '/bookings/$id/check-in';
  static String checkoutRequest(String id) => '/bookings/$id/checkout/request';
  static String complete(String id) => '/bookings/$id/complete';
  static String sos(String id) => '/bookings/$id/sos';

  // ── Care tasks ────────────────────────────────────────────
  static String tasks(String id) => '/bookings/$id/tasks';
  static String taskComplete(String id, String taskId) =>
      '/bookings/$id/tasks/$taskId/complete';
  static String taskSkip(String id, String taskId) =>
      '/bookings/$id/tasks/$taskId/skip';

  // ── GPS tracking ─────────────────────────────────────────
  static String postGps(String id) => '/bookings/$id/gps';
  static String latestGps(String id) => '/bookings/$id/gps/latest';
  static String gpsTracks(String id) => '/bookings/$id/gps-tracks';

  // ── Timeline ─────────────────────────────────────────────
  static String timeline(String id) => '/bookings/$id/timeline';

  // ── Catalog / Services ─────────────────────────────────
  static const services = '/services';
  static String service(String id) => '/services/$id';

  // ── Addresses ────────────────────────────────────────────
  static const addresses = '/addresses';
  static String addressById(String id) => '/addresses/$id';

  // ── Caregivers ───────────────────────────────────────────
  static const caregivers = '/caregivers';
  static String caregiver(String id) => '/caregivers/$id';

  // ── Auth ─────────────────────────────────────────────────
  static const login = '/auth/login';             // POST: login bằng OTP
  static const loginPassword = '/auth/login/password'; // POST: login bằng password
  static const register = '/auth/register';        // POST: đăng ký
  static const sendOtp = '/auth/send-otp';         // POST: gửi OTP qua email
  static const logout = '/auth/logout';            // POST: đăng xuất
  static const me = '/profile';                   // GET: thông tin user hiện tại (ProfileController)

  // ── Support / Review / Disputes ───────────────────────────
  static const reviews = '/reviews';
  static String caregiverReviews(String caregiverId) => '/reviews/caregiver/$caregiverId';
  static const disputes = '/disputes';
  static String dispute(String id) => '/disputes/$id';
}
