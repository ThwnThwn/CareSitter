import 'package:flutter/material.dart';
import 'package:caresitter_customer/features/auth/presentation/screens/password_recovery_screen.dart';
import 'package:caresitter_customer/features/auth/presentation/screens/recovery_email_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/features/auth/presentation/screens/login_screen.dart';
import 'package:caresitter_customer/features/auth/presentation/screens/register_screen.dart';
import 'package:caresitter_customer/features/auth/presentation/screens/email_input_screen.dart';
import 'package:caresitter_customer/features/auth/presentation/screens/otp_verify_screen.dart';
import 'package:caresitter_customer/features/auth/presentation/screens/brand_intro_screen.dart';
import 'package:caresitter_customer/features/home/presentation/screens/home_screen.dart';
import 'package:caresitter_customer/features/home/presentation/screens/notifications_screen.dart';
import 'package:caresitter_customer/features/home/presentation/screens/activity_screen.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/screens/beneficiary_list_screen.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/screens/beneficiary_create_screen.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/screens/beneficiary_detail_screen.dart';
import 'package:caresitter_customer/features/nutrition/presentation/nutrition_screen.dart';
import 'package:caresitter_customer/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:caresitter_customer/features/booking/presentation/screens/booking_wizard_screen.dart';
import 'package:caresitter_customer/features/booking/presentation/screens/booking_list_screen.dart';
import 'package:caresitter_customer/features/booking/presentation/screens/booking_detail_screen.dart';
import 'package:caresitter_customer/features/booking/presentation/screens/payment_result_screen.dart';
import 'package:caresitter_customer/features/caregiver/presentation/screens/caregiver_list_screen.dart';
import 'package:caresitter_customer/features/caregiver/presentation/screens/caregiver_profile_screen.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/screens/shift_tracking_screen.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/screens/care_timeline_screen.dart';
import 'package:caresitter_customer/features/review/presentation/screens/review_screen.dart';
import 'package:caresitter_customer/features/review/presentation/screens/dispute_screen.dart';
import 'package:caresitter_customer/features/settings/presentation/screens/settings_screen.dart';
import 'package:caresitter_customer/features/settings/presentation/screens/profile_edit_screen.dart';
import 'package:caresitter_customer/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:caresitter_customer/features/settings/presentation/screens/saved_addresses_screen.dart';
import 'package:caresitter_customer/features/settings/presentation/screens/change_password_screen.dart';
import 'package:caresitter_customer/features/settings/presentation/screens/faq_screen.dart';
import 'package:caresitter_customer/features/settings/presentation/screens/support_screen.dart';
import 'package:caresitter_customer/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/screens/beneficiary_edit_screen.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/router/auth_route_redirect.dart';
import 'package:caresitter_customer/core/router/shell_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

// ── Tab transition: chỉ crossfade để không làm mất cảm giác giữ state ──────────
CustomTransitionPage<T> _grabTabPage<T>({
  required LocalKey pageKey,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 120),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

// ── Detail transition: thể hiện quan hệ list → detail ─────────────────────────
CustomTransitionPage<T> _slideUpPage<T>({
  required LocalKey pageKey,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
      final slideAnim = Tween<Offset>(
        begin: const Offset(0.08, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0, 0.7, curve: Curves.easeOut),
        ),
        child: SlideTransition(position: slideAnim, child: child),
      );
    },
  );
}

// ── Modal transition: form / OTP / booking tạm thời ──────────────────────────
CustomTransitionPage<T> _modalPage<T>({
  required LocalKey pageKey,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(position: slide, child: child),
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
      return authRouteRedirect(
        location: state.matchedLocation,
        isAuthenticated: isLoggedIn,
      );
    },
    routes: [
      GoRoute(
          path: '/auth/forgot-password',
          builder: (ctx, state) => const PasswordRecoveryScreen()),
      GoRoute(
          path: '/settings/recovery-email',
          builder: (ctx, state) => const RecoveryEmailScreen()),
      // ── Auth Routes ─────────────────────────────
      GoRoute(
        path: '/auth/login',
        pageBuilder: (ctx, state) => _modalPage(
          pageKey: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/auth/register',
        pageBuilder: (ctx, state) => _modalPage(
          pageKey: state.pageKey,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/auth/email',
        pageBuilder: (ctx, state) => _modalPage(
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
        pageBuilder: (ctx, state) => _modalPage(
          pageKey: state.pageKey,
          child: OtpVerifyScreen(email: state.extra as String? ?? ''),
        ),
      ),
      GoRoute(
        path: '/brand-intro',
        pageBuilder: (ctx, state) => NoTransitionPage(
          key: state.pageKey,
          child: const BrandIntroScreen(),
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
              child: CaregiverListScreen(
                initialQuery: state.uri.queryParameters['q'],
              ),
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
        pageBuilder: (ctx, state) => _modalPage(
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
        pageBuilder: (ctx, state) => _modalPage(
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
            intentId: state.uri.queryParameters['intentId'],
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
        pageBuilder: (ctx, state) => _modalPage(
          pageKey: state.pageKey,
          child: const ProfileEditScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/wallet',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: const WalletScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/addresses',
        pageBuilder: (ctx, state) => _modalPage(
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
        pageBuilder: (ctx, state) => _modalPage(
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
        pageBuilder: (ctx, state) => _modalPage(
          pageKey: state.pageKey,
          child: BeneficiaryEditScreen(id: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/beneficiaries/:id/nutrition',
        pageBuilder: (ctx, state) => _slideUpPage(
          pageKey: state.pageKey,
          child: NutritionScreen(beneficiaryId: state.pathParameters['id']!),
        ),
      ),
    ],
  );
});
