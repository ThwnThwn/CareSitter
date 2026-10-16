import 'package:caresitter_customer/core/theme/app_colors.dart';
import '../widgets/booking_list.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_list_top_padding_unread_count_content.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_list_sliver_tab_bar_delegate.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final unreadCount = ref
            .watch(notificationsProvider)
            .valueOrNull
            ?.where((notification) => !notification.isRead)
            .length ??
        0;
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
                indicatorColor: AppColors.primary,
                indicatorWeight: 2.5,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textHint,
                labelStyle: const TextStyle(
                    fontSize: AppFontSizes.s14, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(
                    fontSize: AppFontSizes.s14, fontWeight: FontWeight.w400),
                tabs: const [
                  Tab(text: 'Sắp tới'),
                  Tab(text: 'Hoàn tất'),
                  Tab(text: 'Đã hủy'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: const [
            BookingList(statuses: [
              'draft',
              'pending',
              'pending_payment',
              'payment_reconciliation_pending',
              'needs_manual_review',
              'confirmed',
              'caregiver_accepted',
              'caregiver_en_route',
              'in_progress',
              'checkout_pending_review',
              'crisis',
            ]),
            BookingList(statuses: ['completed']),
            BookingList(
                statuses: ['cancelled', 'matching_failed', 'disputed', 'refunded']),
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

// ── Action icon button ─────────────────────────────────────────────────────

// ── Sliver TabBar Delegate ──────────────────────────────────────────────────
