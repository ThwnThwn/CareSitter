import 'package:caresitter_customer/features/booking/presentation/widgets/booking_list_screen_booking_list.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_list_screen_empty_state.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_list_screen_booking_card.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_list_top_padding_unread_count_content.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_list_sliver_tab_bar_delegate.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
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
          children: [
            _buildBookingList([
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
            _buildBookingList(['completed']),
            _buildBookingList(
                ['cancelled', 'matching_failed', 'disputed', 'refunded']),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingList(List<String> statuses) =>
      BookingListScreenBookingList(
          ref: ref,
          statuses: statuses,
          buildEmptyState: _buildEmptyState,
          buildBookingCard: _buildBookingCard);

  Widget _buildEmptyState() => const BookingListScreenEmptyState();

  Widget _buildBookingCard(BookingModel booking) =>
      BookingListScreenBookingCard(
          booking: booking, formatCurrencyFull: _formatCurrencyFull);

  String _formatCurrencyFull(double amount) {
    return formatVnd(amount);
  }
}

// ── Action icon button ─────────────────────────────────────────────────────

// ── Sliver TabBar Delegate ──────────────────────────────────────────────────
