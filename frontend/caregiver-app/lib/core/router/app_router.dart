import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_notifier.dart';
import 'shell_scaffold.dart';

import '../../features/auth/presentation/screens/phone_input_screen.dart';
import '../../features/auth/presentation/screens/otp_verify_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/notifications_screen.dart';
import '../../features/shifts/presentation/shift_list_screen.dart';
import '../../features/shifts/presentation/shift_detail_screen.dart';
import '../../features/shifts/presentation/shift_active_screen.dart';
import '../../features/shifts/presentation/shift_map_screen.dart';
import '../../features/shifts/presentation/shift_summary_screen.dart';
import '../../features/schedule/presentation/schedule_screen.dart';
import '../../features/earnings/presentation/earnings_screen.dart';
import '../../features/earnings/presentation/withdrawal_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/document_status_screen.dart';
import '../../features/settings/presentation/profile_edit_screen.dart';
import '../../features/settings/presentation/document_upload_screen.dart';
import '../../features/settings/presentation/reviews_screen.dart';
import '../../features/settings/presentation/faq_screen.dart';
import '../../features/settings/presentation/support_screen.dart';
import '../../features/shifts/presentation/shift_customer_report_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

CustomTransitionPage<T> _tabPage<T>({
  required LocalKey pageKey,
  required Widget child,
}) =>
    CustomTransitionPage<T>(
      key: pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 120),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
          return child;
        }
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );

CustomTransitionPage<T> _detailPage<T>({
  required LocalKey pageKey,
  required Widget child,
}) =>
    CustomTransitionPage<T>(
      key: pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
          return child;
        }
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0, 0.7, curve: Curves.easeOut),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );

CustomTransitionPage<T> _modalPage<T>({
  required LocalKey pageKey,
  required Widget child,
}) =>
    CustomTransitionPage<T>(
      key: pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
          return child;
        }
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.12),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );

final appRouterProvider = Provider<GoRouter>((ref) {
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
        pageBuilder: (ctx, state) =>
            _modalPage(pageKey: state.pageKey, child: const PhoneInputScreen()),
      ),
      GoRoute(
        path: '/auth/otp',
        pageBuilder: (ctx, state) {
          final email = state.extra as String? ?? '';
          return _modalPage(
            pageKey: state.pageKey,
            child: OtpVerifyScreen(email: email),
          );
        },
      ),
      GoRoute(
        path: '/auth/register',
        pageBuilder: (ctx, state) =>
            _modalPage(pageKey: state.pageKey, child: const RegisterScreen()),
      ),

      // ── Shell (Bottom Nav) ───────────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (ctx, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (ctx, state) =>
                _tabPage(pageKey: state.pageKey, child: const HomeScreen()),
          ),
          GoRoute(
            path: '/shifts',
            pageBuilder: (ctx, state) => _tabPage(
                pageKey: state.pageKey, child: const ShiftListScreen()),
          ),
          GoRoute(
            path: '/schedule',
            pageBuilder: (ctx, state) =>
                _tabPage(pageKey: state.pageKey, child: const ScheduleScreen()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (ctx, state) =>
                _tabPage(pageKey: state.pageKey, child: const SettingsScreen()),
          ),
        ],
      ),

      // ── Sub-routes ─────────────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/notifications',
        pageBuilder: (ctx, state) => _detailPage(
            pageKey: state.pageKey, child: const NotificationsScreen()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/profile/setup',
        pageBuilder: (ctx, state) => _modalPage(
            pageKey: state.pageKey, child: const ProfileEditScreen()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/profile/documents',
        pageBuilder: (ctx, state) => _detailPage(
            pageKey: state.pageKey, child: const DocumentStatusScreen()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/shifts/:id',
        pageBuilder: (ctx, state) {
          final id = state.pathParameters['id']!;
          return _detailPage(
              pageKey: state.pageKey, child: ShiftDetailScreen(id: id));
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/shifts/:id/active',
        pageBuilder: (ctx, state) {
          final id = state.pathParameters['id']!;
          return _detailPage(
              pageKey: state.pageKey, child: ShiftActiveScreen(id: id));
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/shifts/:id/map',
        pageBuilder: (ctx, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return _detailPage(
            pageKey: state.pageKey,
            child: ShiftMapScreen(
              bookingId: id,
              beneficiaryName:
                  extra['beneficiaryName'] as String? ?? 'Khách hàng',
              address: extra['address'] as String? ?? 'Địa chỉ khách hàng',
              destinationLatitude:
                  (extra['addressLatitude'] as num?)?.toDouble(),
              destinationLongitude:
                  (extra['addressLongitude'] as num?)?.toDouble(),
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/shifts/:id/summary',
        pageBuilder: (ctx, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return _detailPage(
            pageKey: state.pageKey,
            child: ShiftSummaryScreen(
              bookingId: id,
              beneficiaryName:
                  extra['beneficiaryName'] as String? ?? 'Khách hàng',
              caregiverName:
                  extra['caregiverName'] as String? ?? 'Người chăm sóc',
              caregiverEarning: extra['caregiverEarning'] as double? ?? 0.0,
              completedTasks: extra['completedTasks'] as int? ?? 0,
              totalTasks: extra['totalTasks'] as int? ?? 0,
              duration: extra['duration'] as String? ?? '0 giờ',
              checkInTime: extra['checkInTime'] as String? ?? '08:00',
              caregiverNote: extra['caregiverNote'] as String? ?? '',
              taskPhotos:
                  (extra['taskPhotos'] as List<dynamic>? ?? []).cast<String>(),
              checkoutPendingReview:
                  extra['checkoutPendingReview'] as bool? ?? false,
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/shifts/:id/customer-report',
        pageBuilder: (ctx, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return _detailPage(
            pageKey: state.pageKey,
            child: ShiftCustomerReportScreen(
              bookingId: id,
              beneficiaryName:
                  extra['beneficiaryName'] as String? ?? 'Khách hàng',
              caregiverName:
                  extra['caregiverName'] as String? ?? 'Người chăm sóc',
              caregiverEarning: extra['caregiverEarning'] as double? ?? 0.0,
              completedTasks: extra['completedTasks'] as int? ?? 0,
              totalTasks: extra['totalTasks'] as int? ?? 0,
              duration: extra['duration'] as String? ?? '0 giờ',
              checkInTime: extra['checkInTime'] as String? ?? '08:00',
              caregiverNote: extra['caregiverNote'] as String? ?? '',
              taskPhotos:
                  (extra['taskPhotos'] as List<dynamic>? ?? []).cast<String>(),
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/earnings',
        pageBuilder: (ctx, state) =>
            _detailPage(pageKey: state.pageKey, child: const EarningsScreen()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/earnings/withdraw',
        pageBuilder: (ctx, state) =>
            _modalPage(pageKey: state.pageKey, child: const WithdrawalScreen()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/profile/edit',
        pageBuilder: (ctx, state) => _modalPage(
            pageKey: state.pageKey, child: const ProfileEditScreen()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/documents',
        pageBuilder: (ctx, state) => _detailPage(
            pageKey: state.pageKey, child: const DocumentStatusScreen()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/documents/upload',
        pageBuilder: (ctx, state) {
          final docTitle = state.extra as String? ?? 'Tài liệu';
          return _modalPage(
            pageKey: state.pageKey,
            child: DocumentUploadScreen(docTitle: docTitle),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/reviews',
        pageBuilder: (ctx, state) =>
            _detailPage(pageKey: state.pageKey, child: const ReviewsScreen()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/faq',
        pageBuilder: (ctx, state) =>
            _detailPage(pageKey: state.pageKey, child: const FaqScreen()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/support',
        pageBuilder: (ctx, state) =>
            _detailPage(pageKey: state.pageKey, child: const SupportScreen()),
      ),
    ],
  );
});
