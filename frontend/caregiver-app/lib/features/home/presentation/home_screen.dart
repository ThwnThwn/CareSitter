import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/shift_status_style.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../shifts/presentation/providers/shifts_provider.dart';
import '../../earnings/presentation/providers/earnings_provider.dart';
import '../../profile/presentation/providers/profile_provider.dart';
import 'providers/notifications_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final profile = ref.watch(profileProvider);
    final unreadNotifs = ref.watch(notificationsProvider.notifier).unreadCount;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _HomeHeaderDelegate(
              topPadding: topPadding,
              avatar: profile.avatarInitial,
              name: profile.name,
              unreadCount: unreadNotifs,
              onNotificationTap: () => context.push('/notifications'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                _buildDocumentWarning(),
                const SizedBox(height: 16),
                _buildAvailabilityToggle(profile),
                const SizedBox(height: 24),
                _buildNewShiftAlert(profile.isAvailable),
                const SizedBox(height: 24),
                _buildEarningsCard(),
                const SizedBox(height: 24),
                _buildUpcomingShifts(context),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Document Warning (FR-CG-20) ──────────────────────────────
  Widget _buildDocumentWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.error),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Giấy khám sức khoẻ sắp hết hạn',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Vui lòng cập nhật trong vòng 7 ngày tới.',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/settings/documents'),
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
  }

  // ── Availability Toggle (FR-CG-05) ───────────────────────────
  Widget _buildAvailabilityToggle(MockCaregiver profile) {
    final isAvailable = profile.isAvailable;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isAvailable
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.textHint.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAvailable ? Icons.directions_run_rounded : Icons.pause_circle_outline_rounded,
              color: isAvailable ? AppColors.success : AppColors.textHint,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAvailable ? 'Sẵn sàng nhận việc' : 'Đang bận',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  isAvailable ? 'Hệ thống sẽ gợi ý ca phù hợp' : 'Tạm thời không nhận ca mới',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isAvailable,
            activeTrackColor: AppColors.success,
            onChanged: (val) {
              ref.read(profileProvider.notifier).toggleAvailability();
            },
          ),
        ],
      ),
    );
  }

  // ── New Shift Alert (FR-CG-07) ───────────────────────────────
  Widget _buildNewShiftAlert(bool isAvailable) {
    final pendingShifts = ref.watch(shiftsProvider).where((s) => s.status == 'pending').toList();
    if (!isAvailable || pendingShifts.isEmpty) return const SizedBox.shrink();
    final alertShift = pendingShifts.first;

    String distanceInfo = 'Cách bạn 2.5km • Q.Bình Thạnh';
    if (alertShift.address.contains('Q.5') || alertShift.address.contains('Quận 5') || alertShift.address.contains('Quận 5')) {
      distanceInfo = 'Cách bạn 1.8km • Q.5';
    } else if (alertShift.address.contains('Q.3') || alertShift.address.contains('Quận 3')) {
      distanceInfo = 'Cách bạn 1.2km • Q.3';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Ca mới phù hợp',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              const Text('Vừa xong', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            alertShift.serviceName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(distanceInfo, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${alertShift.date}, ${alertShift.time} (${alertShift.duration})', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(shiftsProvider.notifier).declineBooking(alertShift.id);
                  },
                  child: const Text('Bỏ qua'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push('/shifts/${alertShift.id}'),
                  child: const Text('Xem chi tiết'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Earnings Card (FR-CG-19) ─────────────────────────────────
  Widget _buildEarningsCard() {
    final earnings = ref.watch(earningsProvider);
    final completedCount = 21 + ref.watch(shiftsProvider).where((s) => s.status == 'completed').length;

    return GlassCard(
      onTap: () => context.push('/earnings'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Thu nhập tháng này',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Spacer(),
              Icon(Icons.chevron_right, color: AppColors.textHint),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(earnings.balance),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('₫', style: TextStyle(fontSize: 18, color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('$completedCount ca đã hoàn thành', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const Spacer(),
              const Text('+15% so với tháng trước', style: TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Upcoming Shifts ──────────────────────────────────────────
  Widget _buildUpcomingShifts(BuildContext context) {
    final shifts = ref.watch(shiftsProvider);

    MockBooking? nextShift;
    for (final s in shifts) {
      if (s.status == 'in_progress') {
        nextShift = s;
        break;
      }
    }
    if (nextShift == null) {
      for (final s in shifts) {
        if (s.status == 'confirmed') {
          nextShift = s;
          break;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Ca làm việc sắp tới',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/shifts'),
              child: const Text('Tất cả'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (nextShift != null)
          _buildShiftCard(
            context: context,
            id: nextShift.id,
            beneficiaryName: nextShift.beneficiaryName,
            serviceName: nextShift.serviceName,
            date: nextShift.date,
            time: nextShift.time,
            status: nextShift.status,
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              children: [
                Icon(Icons.event_busy_rounded, size: 36, color: AppColors.textHint),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'Không có ca làm việc sắp tới',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 4),
                Text(
                  'Bật "Sẵn sàng nhận việc" để nhận ca mới',
                  style: TextStyle(color: AppColors.textHint, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildShiftCard({
    required BuildContext context,
    required String id,
    required String beneficiaryName,
    required String serviceName,
    required String date,
    required String time,
    required String status,
  }) {
    final isInProgress = status == 'in_progress';
    final style = ShiftStatusStyle.of(status);
    final statusColor = style.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: ListTile(
          contentPadding: const EdgeInsets.all(AppSpacing.md),
          leading: CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.15),
            child: Text(
              beneficiaryName.substring(0, 1),
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(beneficiaryName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(serviceName, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 12, color: statusColor),
                  const SizedBox(width: 4),
                  Text('$time • $date', style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
                ],
              )
            ],
          ),
          trailing: StatusBadge(label: style.label, color: statusColor),
          onTap: () {
            if (isInProgress) {
              context.push('/shifts/$id/active');
            } else {
              context.push('/shifts/$id');
            }
          },
        ),
      ),
    );
  }
}

class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;
  final String avatar;
  final String name;
  final int unreadCount;
  final VoidCallback onNotificationTap;

  const _HomeHeaderDelegate({
    required this.topPadding,
    required this.avatar,
    required this.name,
    required this.unreadCount,
    required this.onNotificationTap,
  });

  static const double _contentHeight = 148.0;

  @override
  double get minExtent => _contentHeight + topPadding;
  @override
  double get maxExtent => _contentHeight + topPadding;
  @override
  bool shouldRebuild(covariant _HomeHeaderDelegate old) =>
      old.topPadding != topPadding ||
      old.avatar != avatar ||
      old.name != name ||
      old.unreadCount != unreadCount;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E6262), Color(0xFF297979)],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  child: Text(
                    avatar,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Xin chào Caregiver 👋',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 13),
                      ),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                      onPressed: onNotificationTap,
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Color(0xFFFF6B6B), shape: BoxShape.circle),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 0.8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: Color(0xFFFFCC70), size: 15),
                  SizedBox(width: 6),
                  Text('4.9/5.0 Đánh giá', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
