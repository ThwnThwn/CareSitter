import 'package:caresitter_customer/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class BookingListSliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  BookingListSliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => _tabBar.preferredSize.height + 1;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          _tabBar,
          const Divider(height: 1, color: AppColors.divider),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(BookingListSliverTabBarDelegate oldDelegate) =>
      _tabBar != oldDelegate._tabBar;
}
