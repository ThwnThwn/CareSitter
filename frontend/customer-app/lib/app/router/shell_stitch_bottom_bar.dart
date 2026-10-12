import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/app/router/shell_center_booking_action.dart';
import 'package:caresitter_customer/app/router/shell_nav_item.dart';
import 'package:caresitter_customer/app/router/shell_nav_bar_item.dart';

class ShellStitchBottomBar extends StatelessWidget {
  final int selectedIndex;
  final int activeTrackingCount;
  final List<ShellNavItem> tabs;
  final void Function(int) onTabSelected;
  final VoidCallback onCreateBooking;

  const ShellStitchBottomBar(
      {super.key,
      required this.selectedIndex,
      required this.activeTrackingCount,
      required this.tabs,
      required this.onTabSelected,
      required this.onCreateBooking});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 64,
                maxWidth: AppLayout.appContentMaxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    ..._buildLeftTabs(),
                    Expanded(
                      child: ShellCenterBookingAction(onTap: onCreateBooking),
                    ),
                    ..._buildRightTabs(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLeftTabs() {
    return [0, 1].map((i) {
      return Expanded(
        child: ShellNavBarItem(
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
        child: ShellNavBarItem(
          item: tabs[i],
          isSelected: selectedIndex == i,
          badgeCount: badge,
          onTap: () => onTabSelected(i),
        ),
      );
    }).toList();
  }
}
