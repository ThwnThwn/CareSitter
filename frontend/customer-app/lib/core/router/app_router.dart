import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/screens/phone_input_screen.dart';
import '../../features/auth/presentation/screens/otp_verify_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/notifications_screen.dart';
import '../../features/beneficiary/presentation/screens/beneficiary_list_screen.dart';
import '../../features/beneficiary/presentation/screens/beneficiary_create_screen.dart';
import '../../features/beneficiary/presentation/screens/beneficiary_detail_screen.dart';
import '../../features/catalog/presentation/catalog_screen.dart';
import '../../features/booking/presentation/screens/booking_wizard_screen.dart';
import '../../features/booking/presentation/screens/booking_list_screen.dart';
import '../../features/booking/presentation/screens/booking_detail_screen.dart';
import '../../features/caregiver/presentation/caregiver_list_screen.dart';
import '../../features/caregiver/presentation/caregiver_profile_screen.dart';
import '../../features/shift_tracking/presentation/shift_tracking_screen.dart';
import '../../features/shift_tracking/presentation/care_timeline_screen.dart';
import '../../features/review/presentation/review_screen.dart';
import '../../features/review/presentation/dispute_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/profile_edit_screen.dart';
import '../../features/settings/presentation/payment_methods_screen.dart';
import '../../features/settings/presentation/saved_addresses_screen.dart';
import '../../features/settings/presentation/change_password_screen.dart';
import '../../features/settings/presentation/two_factor_auth_screen.dart';
import '../../features/settings/presentation/faq_screen.dart';
import '../../features/settings/presentation/support_screen.dart';
import '../../features/beneficiary/presentation/screens/beneficiary_edit_screen.dart';
import '../auth/auth_notifier.dart';
import 'shell_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final appRouterProvider = Provider<GoRouter>((ref) {
  // Dựng GoRouter MỘT lần. Thay vì ref.watch (sẽ dựng lại toàn bộ router +
  // mất nav stack mỗi lần auth đổi), ta cầu nối auth state sang một Listenable
  // để chỉ re-evaluate `redirect` khi cần.
  final refreshSignal = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, __) => refreshSignal.value++);
  ref.onDispose(refreshSignal.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: refreshSignal,
    redirect: (context, state) {
      final isLoggedIn =
          ref.read(authStateProvider).value?.isAuthenticated ?? false;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      if (!isLoggedIn && !isAuthRoute) return '/auth/phone';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      // ── Auth Routes ─────────────────────────────
      GoRoute(
        path: '/auth/phone',
        builder: (ctx, state) => const PhoneInputScreen(),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (ctx, state) {
          final phone = state.extra as String? ?? '';
          return OtpVerifyScreen(phone: phone);
        },
      ),

      // ── Shell (Bottom Nav) ───────────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (ctx, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (ctx, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/bookings',
            builder: (ctx, state) => const BookingListScreen(),
          ),
          GoRoute(
            path: '/beneficiaries',
            builder: (ctx, state) => const BeneficiaryListScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (ctx, state) => const SettingsScreen(),
          ),
        ],
      ),

      // ── Beneficiary ──────────────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/beneficiaries/create',
        builder: (ctx, state) => const BeneficiaryCreateScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/beneficiaries/:id',
        builder: (ctx, state) =>
            BeneficiaryDetailScreen(id: state.pathParameters['id']!),
      ),

      // ── Catalog ──────────────────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/catalog',
        builder: (ctx, state) => const CatalogScreen(),
      ),

      // ── Notifications ─────────────────────────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/notifications',
        builder: (ctx, state) => const NotificationsScreen(),
      ),

      // ── Booking ──────────────────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/booking/new',
        builder: (ctx, state) {
          final serviceId = state.uri.queryParameters['serviceId'];
          return BookingWizardScreen(initialServiceId: serviceId);
        },
      ),
      // ── Shift Tracking ───────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/bookings/:id/tracking',
        builder: (ctx, state) =>
            ShiftTrackingScreen(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/bookings/:id/timeline',
        builder: (ctx, state) =>
            CareTimelineScreen(bookingId: state.pathParameters['id']!),
      ),

      // ── Review & Dispute ─────────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/bookings/:id/review',
        builder: (ctx, state) =>
            ReviewScreen(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/bookings/:id/dispute',
        builder: (ctx, state) =>
            DisputeScreen(bookingId: state.pathParameters['id']!),
      ),

      // ── Booking (generic :id — đặt SAU các sub-route cụ thể) ────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/bookings/:id',
        builder: (ctx, state) =>
            BookingDetailScreen(id: state.pathParameters['id']!),
      ),

      // ── Caregiver ────────────────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/caregivers',
        builder: (ctx, state) => const CaregiverListScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/caregivers/:id',
        builder: (ctx, state) =>
            CaregiverProfileScreen(id: state.pathParameters['id']!),
      ),

      // ── Settings Sub-screens ─────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/profile/edit',
        builder: (ctx, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/payment',
        builder: (ctx, state) => const PaymentMethodsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/addresses',
        builder: (ctx, state) => const SavedAddressesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/password',
        builder: (ctx, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/2fa',
        builder: (ctx, state) => const TwoFactorAuthScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/faq',
        builder: (ctx, state) => const FaqScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/support',
        builder: (ctx, state) => const SupportScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/beneficiaries/:id/edit',
        builder: (ctx, state) =>
            BeneficiaryEditScreen(id: state.pathParameters['id']!),
      ),
    ],
  );
});
