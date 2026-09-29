import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import 'package:caresitter_customer/features/caregiver/presentation/controllers/caregiver_controller.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverProfileScreen extends ConsumerWidget {
  final String id;

  const CaregiverProfileScreen({super.key, required this.id});

  CaregiverModel? _findCaregiver(List<CaregiverModel> caregivers) {
    for (final caregiver in caregivers) {
      if (caregiver.id == id) return caregiver;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caregiverAsync = ref.watch(caregiverStoreProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: caregiverAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (caregivers) {
          final caregiver = _findCaregiver(caregivers);
          if (caregiver == null) {
            return const Center(
              child: Text('Không tìm thấy hồ sơ người chăm sóc'),
            );
          }

          return CustomScrollView(
            slivers: [
              _buildHeader(context, caregiver),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    FadeSlideStaggered(
                      index: 0,
                      child: _buildStatsRow(caregiver),
                    ),
                    const SizedBox(height: 20),
                    FadeSlideStaggered(
                      index: 1,
                      child: _buildSection('Kỹ năng & Chuyên môn',
                          _buildSkillsSection(caregiver)),
                    ),
                    const SizedBox(height: 16),
                    FadeSlideStaggered(
                      index: 2,
                      child: _buildSection(
                          'Giới thiệu', _buildBioSection(caregiver)),
                    ),
                    const SizedBox(height: 16),
                    FadeSlideStaggered(
                      index: 3,
                      child: _buildSection(
                          'Lịch làm việc', _buildScheduleSection()),
                    ),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: caregiverAsync.maybeWhen(
        data: (caregivers) {
          final caregiver = _findCaregiver(caregivers);
          return caregiver == null
              ? const SizedBox.shrink()
              : _buildBottomBar(context, caregiver);
        },
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CaregiverModel caregiver) {
    final textScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8).toDouble();
    final expandedHeight = 280 + ((textScale - 1) * 300);

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      leading: const AppBackButton(
        fallbackRoute: '/caregivers',
        color: Colors.white,
      ),
      actions: [
        _FavoriteButton(caregiverName: caregiver.displayName),
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.white),
          onPressed: () {
            SharePlus.instance.share(
              ShareParams(
                text:
                    'Xem hồ sơ chăm sóc viên ${caregiver.displayName} trên CareSitter!\n'
                    'Đánh giá: ${caregiver.ratingAvg.toStringAsFixed(1)}/5 ⭐',
                subject: 'Hồ sơ Chăm sóc viên - ${caregiver.displayName}',
              ),
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 48),
                Stack(
                  children: [
                    Hero(
                      tag: 'caregiver-avatar-${caregiver.id}',
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        child: Text(
                          caregiver.initials,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    if (caregiver.isOnline)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  caregiver.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.fade,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  caregiver.isOnline
                      ? '● Đang rảnh${caregiver.yearsOfExperience != null ? ' • ${caregiver.yearsOfExperience} năm kinh nghiệm' : ''}'
                      : '○ Hiện đang bận',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, size: 14, color: Color(0xFFF39C12)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${caregiver.ratingAvg.toStringAsFixed(1)} (${caregiver.ratingCount} đánh giá)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                if (caregiver.location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          caregiver.location,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(CaregiverModel caregiver) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem('⭐ ${caregiver.ratingAvg.toStringAsFixed(1)}',
                '${caregiver.ratingCount} đánh giá'),
          ),
          _buildDivider(),
          Expanded(child: _buildStatItem('🛡️ 100%', 'Xác minh KYC')),
          _buildDivider(),
          Expanded(
            child: _buildStatItem(
                '📍 ${caregiver.location.isNotEmpty ? caregiver.location : 'TP.HCM'}',
                'Khu vực'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.fade,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 32,
      width: 1,
      color: AppColors.divider,
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        content,
      ],
    );
  }

  Widget _buildSkillsSection(CaregiverModel caregiver) {
    if (caregiver.skills.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Chưa cập nhật kỹ năng',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: caregiver.skills.map((skill) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline,
                  color: AppColors.primary, size: 14),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  skill,
                  maxLines: 2,
                  overflow: TextOverflow.fade,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBioSection(CaregiverModel caregiver) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Text(
        caregiver.bio != null && caregiver.bio!.isNotEmpty
            ? caregiver.bio!
            : 'Chăm sóc viên tận tâm, chu đáo, được đào tạo bài bản và luôn sẵn sàng hỗ trợ chăm sóc gia đình bạn.',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildScheduleSection() {
    final days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final available = [true, true, true, true, true, true, false];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        return Column(
          children: [
            Text(days[i],
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 6),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: available[i]
                    ? AppColors.successLight
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                available[i] ? Icons.check : Icons.close,
                size: 16,
                color: available[i] ? AppColors.success : AppColors.textHint,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildBottomBar(BuildContext context, CaregiverModel caregiver) {
    final rate = caregiver.hourlyRateExpected ?? 85000;
    final price = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Giá thuê',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        Text(
          '${rate.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}đ/giờ',
          maxLines: 2,
          style: const TextStyle(
              color: AppColors.primary,
              fontSize: 20,
              fontWeight: FontWeight.w800),
        ),
      ],
    );
    final action = ElevatedButton(
      onPressed: caregiver.isOnline ? () => context.push('/booking/new') : null,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        caregiver.isOnline ? 'Đặt lịch ngay' : 'Hiện đang bận',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final stackActions =
              constraints.maxWidth < AppBreakpoints.compact || textScale > 1.2;
          if (stackActions) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [price, const SizedBox(height: 12), action],
            );
          }

          return Row(
            children: [
              Expanded(child: price),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: action),
            ],
          );
        },
      ),
    );
  }
}

// ── Favorite toggle button ─────────────────────────────
class _FavoriteButton extends StatefulWidget {
  final String caregiverName;
  const _FavoriteButton({required this.caregiverName});

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  bool _isFav = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isFav ? Icons.favorite : Icons.favorite_border,
        color: Colors.white,
      ),
      onPressed: () {
        setState(() => _isFav = !_isFav);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFav
                ? 'Đã thêm ${widget.caregiverName} vào yêu thích'
                : 'Đã bỏ yêu thích ${widget.caregiverName}'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }
}
