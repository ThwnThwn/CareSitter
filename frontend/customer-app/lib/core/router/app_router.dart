import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/email_input_screen.dart';
import '../../features/auth/presentation/screens/otp_verify_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/notifications_screen.dart';
import '../../features/home/presentation/activity_screen.dart';
import '../../features/beneficiary/presentation/screens/beneficiary_list_screen.dart';
import '../../features/beneficiary/presentation/screens/beneficiary_create_screen.dart';
import '../../features/beneficiary/presentation/screens/beneficiary_detail_screen.dart';
import '../../features/catalog/presentation/catalog_screen.dart';
import '../../features/booking/presentation/screens/booking_wizard_screen.dart';
import '../../features/booking/presentation/screens/booking_list_screen.dart';
import '../../features/booking/presentation/screens/booking_detail_screen.dart';
import '../../features/booking/presentation/screens/payment_result_screen.dart';
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
import '../../features/settings/presentation/notification_settings_screen.dart';
import '../../features/beneficiary/presentation/screens/beneficiary_edit_screen.dart';
import '../auth/auth_notifier.dart';
import 'shell_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

// ── Grab-style tab transition: micro-slide từ phải + fade ─────────────────────
CustomTransitionPage<T> _grabTabPage<T>({
  required LocalKey pageKey,
  required Widget child,
}) {
  // Spring curve giống Grab app: ease-out cực nhanh, landing mềm
  const spring = Cubic(0.16, 1.0, 0.30, 1.0);

  return CustomTransitionPage<T>(
    key: pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Slide: 3% từ phải sang (micro — vừa đủ thấy, không làm mất focus)
      final slideIn = Tween<Offset>(
        begin: const Offset(0.03, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: spring));

      // Fade: 0 → 1 nhanh ở đầu
      final fadeIn = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      );

      // Secondary (trang cũ đi ra): fade ra mềm + slide nhẹ sang trái
      final slideOut = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.015, 0),
      ).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn));
      final fadeOut = Tween<double>(begin: 1.0, end: 0.85).animate(
        CurvedAnimation(
            parent: secondaryAnimation,
            curve: const Interval(0.0, 0.8, curve: Curves.easeIn)),
      );

      return SlideTransition(
        position: slideOut,
        child: FadeTransition(
          opacity: fadeOut,
          child: SlideTransition(
            position: slideIn,
            child: FadeTransition(
              opacity: fadeIn,
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

// ── Slide-up + Fade transition (dùng cho màn hình detail push lên trên) ─────
CustomTransitionPage<T> _slideUpPage<T>({
  required LocalKey pageKey,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.25),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(position: slideAnim, child: child),
      );
    },
  );
}

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
      if (!isLoggedIn && !isAuthRoute) return '/auth/login';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      // ── Auth Routes ─────────────────────────────
      GoRoute(
        path: '/auth/login',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/auth/register',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/auth/email',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: const EmailInputScreen(),
        ),
      ),
      GoRoute(
        path: '/auth/phone',
        redirect: (ctx, state) => '/auth/email',
      ),
      GoRoute(
        path: '/auth/otp',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: OtpVerifyScreen(email: state.extra as String? ?? ''),
        ),
      ),

      // ── Shell (Bottom Nav) ───────────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (ctx, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (ctx, state) => _grabTabPage(
              pageKey: state.pageKey,
              child: const HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/bookings',
            pageBuilder: (ctx, state) => _grabTabPage(
              pageKey: state.pageKey,
              child: const BookingListScreen(),
            ),
          ),
          GoRoute(
            path: '/caregivers',
            pageBuilder: (ctx, state) => _grabTabPage(
              pageKey: state.pageKey,
              child: const CaregiverListScreen(),
            ),
          ),
          GoRoute(
            path: '/beneficiaries',
            pageBuilder: (ctx, state) => _grabTabPage(
              pageKey: state.pageKey,
              child: const BeneficiaryListScreen(),
            ),
          ),
          GoRoute(
            path: '/tracking',
            pageBuilder: (ctx, state) => _grabTabPage(
              pageKey: state.pageKey,
              child: const ActivityScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (ctx, state) => _grabTabPage(
              pageKey: state.pageKey,
              child: const SettingsScreen(),
            ),
          ),
        ],
      ),

      // ── Beneficiary ──────────────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/beneficiaries/create',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: const BeneficiaryCreateScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/beneficiaries/:id',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: BeneficiaryDetailScreen(id: state.pathParameters['id']!),
        ),
      ),

      // ── Catalog ──────────────────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/catalog',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: const CatalogScreen(),
        ),
      ),

      // ── Notifications ─────────────────────────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/notifications',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: const NotificationsScreen(),
        ),
      ),

      // ── Booking ──────────────────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/booking/new',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: BookingWizardScreen(
            initialServiceId: state.uri.queryParameters['serviceId'],
            initialBeneficiaryId: state.uri.queryParameters['beneficiaryId'],
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/payment-result',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: PaymentResultScreen(
            bookingId: state.uri.queryParameters['bookingId'],
            result: state.uri.queryParameters['result'] ?? 'failed',
          ),
        ),
      ),
      // ── Shift Tracking ───────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/bookings/:id/tracking',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: ShiftTrackingScreen(bookingId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/bookings/:id/timeline',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: CareTimelineScreen(bookingId: state.pathParameters['id']!),
        ),
      ),

      // ── Review & Dispute ─────────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/bookings/:id/review',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: ReviewScreen(bookingId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/bookings/:id/dispute',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: DisputeScreen(bookingId: state.pathParameters['id']!),
        ),
      ),

      // ── Booking (generic :id — đặt SAU các sub-route cụ thể) ────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/bookings/:id',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: BookingDetailScreen(id: state.pathParameters['id']!),
        ),
      ),

      // ── Caregiver ────────────────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/caregivers/:id',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: CaregiverProfileScreen(id: state.pathParameters['id']!),
        ),
      ),

      // ── Settings Sub-screens ─────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/profile/edit',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: const ProfileEditScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/payment',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: const PaymentMethodsScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/addresses',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: SavedAddressesScreen(
            selectionMode: state.uri.queryParameters['select'] == '1',
            selectedAddressId: state.uri.queryParameters['selected'],
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/password',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: const ChangePasswordScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/notifications',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: const NotificationSettingsScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/2fa',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: const TwoFactorAuthScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/faq',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: const FaqScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/support',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: const SupportScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/beneficiaries/:id/edit',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: BeneficiaryEditScreen(id: state.pathParameters['id']!),
        ),
      ),
    ],
  );
});
