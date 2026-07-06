import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_notifier.dart';
import 'shell_scaffold.dart';

import '../../features/auth/presentation/screens/phone_input_screen.dart';
import '../../features/auth/presentation/screens/otp_verify_screen.dart';
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
            path: '/shifts',
            builder: (ctx, state) => const ShiftListScreen(),
          ),
          GoRoute(
            path: '/schedule',
            builder: (ctx, state) => const ScheduleScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (ctx, state) => const SettingsScreen(),
          ),
        ],
      ),

      // ── Sub-routes ─────────────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/notifications',
        builder: (ctx, state) => const NotificationsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/profile/setup',
        builder: (ctx, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/profile/documents',
        builder: (ctx, state) => const DocumentStatusScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/shifts/:id',
        builder: (ctx, state) {
          final id = state.pathParameters['id']!;
          return ShiftDetailScreen(id: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/shifts/:id/active',
        builder: (ctx, state) {
          final id = state.pathParameters['id']!;
          return ShiftActiveScreen(id: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/shifts/:id/map',
        builder: (ctx, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ShiftMapScreen(
            bookingId: id,
            beneficiaryName: extra['beneficiaryName'] as String? ?? 'Khách hàng',
            address: extra['address'] as String? ?? 'Địa chỉ khách hàng',
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/shifts/:id/summary',
        builder: (ctx, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ShiftSummaryScreen(
            bookingId: id,
            beneficiaryName: extra['beneficiaryName'] as String? ?? 'Khách hàng',
            caregiverName: extra['caregiverName'] as String? ?? 'Người chăm sóc',
            caregiverEarning: extra['caregiverEarning'] as double? ?? 0.0,
            completedTasks: extra['completedTasks'] as int? ?? 0,
            totalTasks: extra['totalTasks'] as int? ?? 0,
            duration: extra['duration'] as String? ?? '0 giờ',
            checkInTime: extra['checkInTime'] as String? ?? '08:00',
            caregiverNote: extra['caregiverNote'] as String? ?? '',
            taskPhotos:
                (extra['taskPhotos'] as List<dynamic>? ?? []).cast<String>(),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/shifts/:id/customer-report',
        builder: (ctx, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ShiftCustomerReportScreen(
            bookingId: id,
            beneficiaryName: extra['beneficiaryName'] as String? ?? 'Khách hàng',
            caregiverName: extra['caregiverName'] as String? ?? 'Người chăm sóc',
            caregiverEarning: extra['caregiverEarning'] as double? ?? 0.0,
            completedTasks: extra['completedTasks'] as int? ?? 0,
            totalTasks: extra['totalTasks'] as int? ?? 0,
            duration: extra['duration'] as String? ?? '0 giờ',
            checkInTime: extra['checkInTime'] as String? ?? '08:00',
            caregiverNote: extra['caregiverNote'] as String? ?? '',
            taskPhotos:
                (extra['taskPhotos'] as List<dynamic>? ?? []).cast<String>(),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/earnings',
        builder: (ctx, state) => const EarningsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/earnings/withdraw',
        builder: (ctx, state) => const WithdrawalScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/profile/edit',
        builder: (ctx, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/documents',
        builder: (ctx, state) => const DocumentStatusScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/documents/upload',
        builder: (ctx, state) {
          final docTitle = state.extra as String? ?? 'Tài liệu';
          return DocumentUploadScreen(docTitle: docTitle);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/reviews',
        builder: (ctx, state) => const ReviewsScreen(),
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
    ],
  );
});
