import 'package:caresitter_customer/core/theme/app_colors.dart';
import '../widgets/booking_list.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_list_top_padding_unread_count_content.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_list_sliver_tab_bar_delegate.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/features/booking/domain/booking_status_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/features/home/presentation/controllers/notifications_controller.dart';

class BookingListScreen extends ConsumerStatefulWidget {
  const BookingListScreen({super.key});

  @override
  ConsumerState<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends ConsumerState<BookingListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: BookingListCategory.values.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final tabTextScale =
        MediaQuery.textScalerOf(context).scale(AppFontSizes.s14) /
            AppFontSizes.s14;
    final useScrollableTabs = screenWidth < 520 || tabTextScale > 1.2;
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          BookingListTopPaddingUnreadCountContent(
              topPadding: topPadding, unreadCount: unreadCount),
          SliverPersistentHeader(
            pinned: true,
            delegate: BookingListSliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                isScrollable: useScrollableTabs,
                tabAlignment:
                    useScrollableTabs ? TabAlignment.start : TabAlignment.fill,
                labelPadding: EdgeInsets.symmetric(
                  horizontal: useScrollableTabs ? 16 : 4,
                ),
                indicatorColor: AppColors.primary,
                indicatorWeight: 2.5,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textHint,
                labelStyle: const TextStyle(
                    fontSize: AppFontSizes.s14, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(
                    fontSize: AppFontSizes.s14, fontWeight: FontWeight.w400),
                tabs: [
                  for (final category in BookingListCategory.values)
                    Tab(
                        text: switch (category) {
                      BookingListCategory.active => 'Đang xử lý',
                      BookingListCategory.completed => 'Hoàn tất',
                      BookingListCategory.unmatched => 'Chưa ghép',
                      BookingListCategory.disputed => 'Khiếu nại',
                      BookingListCategory.cancelled => 'Hủy / hoàn tiền',
                    }),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            for (final category in BookingListCategory.values)
              BookingList(category: category),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
