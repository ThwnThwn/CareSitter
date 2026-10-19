import 'package:caresitter_customer/app/router/shell_stitch_bottom_bar.dart';
import 'package:caresitter_customer/app/router/shell_nav_item.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ShellScaffold extends StatelessWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  static const _tabs = [
    ShellNavItem(icon: Icons.home_outlined, label: 'Trang chủ', path: '/home'),
    ShellNavItem(
        icon: Icons.calendar_month_outlined,
        label: 'Lịch hẹn',
        path: '/bookings'),
    ShellNavItem(
        icon: Icons.restaurant_menu_outlined,
        label: 'Thực đơn',
        path: '/nutrition'),
    ShellNavItem(
        icon: Icons.person_outline_rounded, label: 'Hồ sơ', path: '/settings'),
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _selectedIndex(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.appContentMaxWidth,
          ),
          child: child,
        ),
      ),
      backgroundColor: AppColors.background,
      // Reserve the bottom bar's full height so scrollable page content never
      // gets trapped underneath the persistent navigation.
      extendBody: false,
      bottomNavigationBar: ShellStitchBottomBar(
        selectedIndex: idx,
        tabs: _tabs,
        onTabSelected: (i) => context.go(_tabs[i].path),
        onCreateBooking: () => context.push('/booking/new'),
      ),
    );
  }
}

// ── Center FAB (GlowCare-style floating button) ────────────────────────────

// ── Bottom Bar (GlowCare-style) ────────────────────────────────────────────

// ── Nav Item ───────────────────────────────────────────────────────────────
