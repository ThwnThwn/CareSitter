import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/app/router/shell_nav_item.dart';

class ShellNavBarItem extends StatelessWidget {
  final ShellNavItem item;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  const ShellNavBarItem(
      {super.key,
      required this.item,
      required this.isSelected,
      required this.onTap,
      this.badgeCount = 0});

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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding:
                        isSelected ? const EdgeInsets.all(4) : EdgeInsets.zero,
                    decoration: isSelected
                        ? BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          )
                        : null,
                    child: Icon(
                      item.icon,
                      color:
                          isSelected ? AppColors.primary : AppColors.textHint,
                      size: isSelected ? 20 : 24,
                    ),
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
                        color: AppColors.error,
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
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textHint,
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
