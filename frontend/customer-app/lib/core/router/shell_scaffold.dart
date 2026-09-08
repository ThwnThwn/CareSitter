import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/booking/application/booking_store.dart';
import '../theme/app_theme.dart';

class ShellScaffold extends ConsumerWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  static const _tabs = [
    _NavItem(icon: Icons.home_rounded, label: 'Trang chủ', path: '/home'),
    _NavItem(
        icon: Icons.calendar_month_rounded,
        label: 'Lịch hẹn',
        path: '/bookings'),
    _NavItem(
        icon: Icons.people_alt_rounded,
        label: 'Caregiver',
        path: '/caregivers'),
    _NavItem(
        icon: Icons.person_outline_rounded, label: 'Hồ sơ', path: '/settings'),
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = _selectedIndex(context);

    // Tính số lượng ca đang diễn ra (cần theo dõi) thật từ bookingStore
    final bookings = ref.watch(bookingStoreProvider);
    final activeTrackingCount = bookings.where((b) {
      final s = b.status.toLowerCase();
      return s == 'in_progress' ||
          s == 'caregiver_en_route' ||
          s == 'checkout_pending_review';
    }).length;

    return Scaffold(
      body: child,
      backgroundColor: AppColors.background,
      extendBody: true,
      floatingActionButton: _CenterFab(
        onTap: () => context.push('/booking/new'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _StitchBottomBar(
        selectedIndex: idx,
        activeTrackingCount: activeTrackingCount,
        tabs: _tabs,
        onTabSelected: (i) => context.go(_tabs[i].path),
      ),
    );
  }
}

// ── Center FAB ─────────────────────────────────────────────────────────────
class _CenterFab extends StatelessWidget {
  final VoidCallback onTap;
  const _CenterFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}

// ── Bottom Bar ─────────────────────────────────────────────────────────────
class _StitchBottomBar extends StatelessWidget {
  final int selectedIndex;
  final int activeTrackingCount;
  final List<_NavItem> tabs;
  final void Function(int) onTabSelected;

  const _StitchBottomBar({
    required this.selectedIndex,
    required this.activeTrackingCount,
    required this.tabs,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.white,
      elevation: 0,
      notchMargin: 8,
      shape: const AutomaticNotchedShape(
        RoundedRectangleBorder(),
        CircleBorder(),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFE8F2EC), width: 1),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                // Tab 0 & 1 — left side
                ..._buildLeftTabs(),
                // Center spacer for FAB
                const SizedBox(width: 72),
                // Tab 2 & 3 — right side
                ..._buildRightTabs(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLeftTabs() {
    return [0, 1].map((i) {
      return Expanded(
        child: _NavBarItem(
          item: tabs[i],
          isSelected: selectedIndex == i,
          badgeCount: 0,
          onTap: () => onTabSelected(i),
        ),
      );
    }).toList();
  }

  List<Widget> _buildRightTabs() {
    return [2, 3].map((i) {
      final badge = i == 2 ? activeTrackingCount : 0;
      return Expanded(
        child: _NavBarItem(
          item: tabs[i],
          isSelected: selectedIndex == i,
          badgeCount: badge,
          onTap: () => onTabSelected(i),
        ),
      );
    }).toList();
  }
}

// ── Nav Item ───────────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  final String path;
  const _NavItem({required this.icon, required this.label, required this.path});
}

class _NavBarItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Icon(
                    item.icon,
                    color: isSelected
                        ? AppColors.primary
                        : const Color(0xFF9CA3AF),
                    size: 24,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE74C3C),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: TextStyle(
              color: isSelected ? AppColors.primary : const Color(0xFF9CA3AF),
              fontSize: 10,
              height: 1.1,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
