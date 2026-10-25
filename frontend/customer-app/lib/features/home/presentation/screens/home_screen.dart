import '../widgets/home_header.dart';
import '../widgets/home_live_session_card.dart';
import '../widgets/home_promotions_section.dart';
import '../widgets/home_promo_card.dart';
import '../widgets/home_recently_booked_section.dart';
import '../widgets/home_rebook_card.dart';
import '../widgets/home_upcoming_appointments_section.dart';
import '../widgets/home_appointment_card.dart';
import '../widgets/home_services_section.dart';
import '../widgets/home_service_card.dart';
import '../widgets/home_caregiver_section.dart';
import '../widgets/home_caregiver_card.dart';
import '../widgets/home_skill_chip.dart';
import '../widgets/home_caregiver_empty_state.dart';
import '../widgets/home_hero_banner.dart';
import '../models/home_service_accent.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:caresitter_customer/features/home/presentation/controllers/notifications_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _caregiverSearchController = TextEditingController();

  @override
  void dispose() {
    _caregiverSearchController.dispose();
    super.dispose();
  }

  void _openCaregiverSearch([String? value]) {
    final query = (value ?? _caregiverSearchController.text).trim();
    final location = AppRoutes.caregiversSearch(query: query);
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(bookingStoreProvider);
    final profile = ref.watch(profileStoreProvider);
    final unreadCount = ref
            .watch(notificationsProvider)
            .valueOrNull
            ?.where((notification) => !notification.isRead)
            .length ??
        0;
    final topPadding = MediaQuery.of(context).padding.top;

    // Chỉ hiện booking thật từ store: ưu tiên ca đang diễn ra,
    // nếu không có thì lấy ca hợp lệ gần nhất trong tương lai.
    final featuredBooking = _selectFeaturedBooking(bookings, DateTime.now());

    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'Nunito'),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Nunito'),
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, profile, topPadding, unreadCount),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    _buildHeroBanner(context),
                    if (featuredBooking != null) ...[
                      const SizedBox(height: AppSpacing.compact),
                      _buildLiveSessionCard(featuredBooking, context),
                    ],
                    const SizedBox(height: AppSpacing.section),
                    _buildServicesSection(context),
                    const SizedBox(height: AppSpacing.lg),
                    _buildPromotionsSection(context),
                    const SizedBox(height: AppSpacing.lg),
                    _buildRecentlyBookedSection(context, bookings),
                    const SizedBox(height: AppSpacing.lg),
                    _buildUpcomingAppointmentsSection(context, bookings),
                    const SizedBox(height: AppSpacing.lg),
                    _buildCaregiverSection(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BookingModel? _selectFeaturedBooking(
    List<BookingModel> bookings,
    DateTime now,
  ) {
    final ongoing = bookings
        .where((booking) => booking.presentationStatusAt(now) == 'in_progress')
        .toList()
      ..sort((a, b) => b.scheduledStart.compareTo(a.scheduledStart));
    if (ongoing.isNotEmpty) return ongoing.first;

    const upcomingStatuses = {
      'confirmed',
      'caregiver_accepted',
      'caregiver_en_route',
    };
    final upcoming = bookings.where((booking) {
      final status = booking.presentationStatusAt(now);
      return upcomingStatuses.contains(status) &&
          booking.scheduledEnd.isAfter(now);
    }).toList()
      ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));

    return upcoming.isEmpty ? null : upcoming.first;
  }

  // ── Header (GlowCare-style) ─────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, UserProfile profile,
          double topPadding, int unreadCount) =>
      HomeHeader(
          profile: profile, topPadding: topPadding, unreadCount: unreadCount);

  // ── Live Session Card ───────────────────────────────────────────────────────
  Widget _buildLiveSessionCard(BookingModel booking, BuildContext context) =>
      HomeLiveSessionCard(booking: booking, formatCurrency: _formatCurrency);

  // ── Promotions Section ────────────────────────────────────────────────────
  Widget _buildPromotionsSection(BuildContext context) =>
      HomePromotionsSection(buildPromoCard: _buildPromoCard);

  Widget _buildPromoCard(
    ({
      String title,
      String subtitle,
      String hsd,
      String badge,
      Color bg,
      Color accent,
      Color borderColor,
      String icon
    }) promo,
  ) =>
      HomePromoCard(promo: promo);

  // ── Recently Booked Section ─────────────────────────────────────────────────
  Widget _buildRecentlyBookedSection(
          BuildContext context, List<BookingModel> bookings) =>
      HomeRecentlyBookedSection(
          bookings: bookings, buildRebookCard: _buildRebookCard);

  Widget _buildRebookCard(BookingModel booking, BuildContext context) =>
      HomeRebookCard(booking: booking);

  // ── Upcoming Appointments Section ───────────────────────────────────────────
  Widget _buildUpcomingAppointmentsSection(
          BuildContext context, List<BookingModel> bookings) =>
      HomeUpcomingAppointmentsSection(
          bookings: bookings, buildAppointmentCard: _buildAppointmentCard);

  Widget _buildAppointmentCard(
          BookingModel booking, DateTime now, BuildContext context) =>
      HomeAppointmentCard(booking: booking, now: now);

  // ── Services Section ────────────────────────────────────────────────────────
  Widget _buildServicesSection(BuildContext context) => HomeServicesSection(
      buildServiceCard: _buildServiceCard, serviceAccent: _serviceAccent);

  Widget _buildServiceCard(ServiceModel service, HomeServiceAccent accent) =>
      HomeServiceCard(service: service, accent: accent, formatVnd: _formatVnd);

  HomeServiceAccent _serviceAccent(int index) {
    const accents = [
      HomeServiceAccent(AppColors.primary, AppColors.primaryContainer),
      HomeServiceAccent(AppColors.warning, AppColors.warningLight),
      HomeServiceAccent(AppColors.primaryDark, AppColors.primaryContainer),
      HomeServiceAccent(AppColors.textSecondary, AppColors.background),
      HomeServiceAccent(AppColors.primary, AppColors.primaryContainer),
      HomeServiceAccent(AppColors.primary, AppColors.primaryContainer),
    ];
    return accents[index % accents.length];
  }

  String _formatVnd(int amount) {
    return formatVnd(amount, zeroLabel: 'Liên hệ');
  }

  // ── Caregiver Section ───────────────────────────────────────────────────────
  Widget _buildCaregiverSection(BuildContext context) => HomeCaregiverSection(
      ref: ref,
      buildCaregiverEmptyState: _buildCaregiverEmptyState,
      buildCaregiverCard: _buildCaregiverCard);

  Widget _buildCaregiverCard(CaregiverModel c, BuildContext context) =>
      HomeCaregiverCard(c: c, buildSkillChip: _buildSkillChip);

  Widget _buildSkillChip(String label) => HomeSkillChip(label: label);

  Widget _buildCaregiverEmptyState(BuildContext context,
          {required bool hasLocation}) =>
      HomeCaregiverEmptyState(hasLocation: hasLocation);

  // Helpers
  String _formatCurrency(double amount) {
    return formatVnd(amount);
  }

  // ── Hero Banner ────────────────────────────────────────────────────────────
  Widget _buildHeroBanner(BuildContext context) => HomeHeroBanner(
      caregiverSearchController: _caregiverSearchController,
      openCaregiverSearch: _openCaregiverSearch);
}
