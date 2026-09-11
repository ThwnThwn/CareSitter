/// API path constants cho CareSitter Caregiver App.
/// baseUrl: --dart-define=BASE_URL=http://localhost:5033/api/v1
library;

const String kBaseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'http://localhost:5033/api/v1',
);

class ApiPaths {
  ApiPaths._();

  // ── Bookings / Shifts ─────────────────────────────────────
  static const bookings = '/bookings';
  static String booking(String id) => '/bookings/$id';

  // ── Lifecycle (caregiver actions) ─────────────────────────
  static String acceptBooking(String id) => '/bookings/$id/accept';
  static String declineBooking(String id) => '/bookings/$id/decline';
  static String enRoute(String id) => '/bookings/$id/en-route';
  static String checkIn(String id) => '/bookings/$id/check-in';
  static String checkoutRequest(String id) => '/bookings/$id/checkout/request';
  static String complete(String id) => '/bookings/$id/complete';
  static String raiseSos(String id) => '/bookings/$id/sos';
  static String timeline(String id) => '/bookings/$id/timeline';

  // ── GPS push ──────────────────────────────────────────────
  static String postGps(String id) => '/bookings/$id/gps';

  // ── Caregiver profile / availability ──────────────────────
  static const myCaregiverProfile = '/caregivers/me/profile';
  static const myAvailability = '/caregivers/me/availability';
  static const myCaregiverStatus = '/caregivers/me/status';

  // ── Wallet / earnings ─────────────────────────────────────
  static const wallet = '/wallet';

  // ── Care tasks ────────────────────────────────────────────
  static String tasks(String id) => '/bookings/$id/tasks';
  static String taskComplete(String id, String taskId) =>
      '/bookings/$id/tasks/$taskId/complete';
  static String taskPhotos(String id, String taskId) =>
      '/bookings/$id/tasks/$taskId/photos';
  static String taskSkip(String id, String taskId) =>
      '/bookings/$id/tasks/$taskId/skip';

  // ── Auth ─────────────────────────────────────────────────
  static const login = '/auth/login';
  static const refreshToken = '/auth/refresh';
}
