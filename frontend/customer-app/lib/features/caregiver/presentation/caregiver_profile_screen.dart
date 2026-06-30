import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/mock/mock_data.dart';

class CaregiverProfileScreen extends StatelessWidget {
  final String id;

  const CaregiverProfileScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final caregiver = MockData.caregivers.firstWhere(
      (c) => c.id == id,
      orElse: () => MockData.caregivers.first,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildHeader(context, caregiver),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildStatsRow(caregiver),
                const SizedBox(height: 20),
                _buildSection(
                    'Kỹ năng & Chuyên môn', _buildSkillsSection(caregiver)),
                const SizedBox(height: 16),
                _buildSection('Chứng chỉ', _buildCertSection(caregiver)),
                const SizedBox(height: 16),
                _buildSection('Đánh giá gần đây', _buildReviewsSection()),
                const SizedBox(height: 16),
                _buildSection('Lịch làm việc', _buildScheduleSection()),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildHeader(BuildContext context, MockCaregiver caregiver) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      leading: const AppBackButton(
        fallbackRoute: '/caregivers',
        color: Colors.white,
      ),
      actions: [
        _FavoriteButton(caregiverName: caregiver.name),
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.white),
          onPressed: () {
            SharePlus.instance.share(
              ShareParams(
                text: 'Xem hồ sơ caregiver ${caregiver.name} trên CareSitter!\n'
                    'Kinh nghiệm: ${caregiver.experience}\n'
                    'Đánh giá: ${caregiver.rating}/5 ⭐',
                subject: 'Hồ sơ Caregiver - ${caregiver.name}',
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
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      child: Text(
                        caregiver.avatarInitial,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (caregiver.isAvailable)
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
                  caregiver.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  caregiver.isAvailable
                      ? '● Đang rảnh • ${caregiver.experience} kinh nghiệm'
                      : '○ Hiện đang bận',
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
                    Text(
                      '${caregiver.rating} (${caregiver.totalReviews} đánh giá)',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      caregiver.location,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(MockCaregiver caregiver) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          _buildStat('${caregiver.completedShifts}', 'Ca hoàn thành',
              Icons.check_circle_outline),
          _buildStatDivider(),
          _buildStat('${caregiver.rating}⭐', 'Đánh giá TB', Icons.star_outline),
          _buildStatDivider(),
          _buildStat(
              '${caregiver.totalReviews}', 'Đánh giá', Icons.reviews_outlined),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(label,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 10),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 40, color: AppColors.divider);
  }

  Widget _buildSection(String title, Widget content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildSkillsSection(MockCaregiver caregiver) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: caregiver.skills.map((skill) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle,
                  size: 13, color: AppColors.primary),
              const SizedBox(width: 5),
              Text(skill,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCertSection(MockCaregiver caregiver) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.workspace_premium,
              color: AppColors.secondary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            caregiver.certifications,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 13, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection() {
    final reviews = [
      {
        'name': 'Nguyễn Văn B',
        'rating': 5,
        'text': 'Rất tận tâm, chăm sóc bố tôi rất chu đáo!',
        'time': '3 ngày trước'
      },
      {
        'name': 'Trần Thị C',
        'rating': 4,
        'text': 'Đúng giờ, chuyên nghiệp. Sẽ đặt lại lần sau.',
        'time': '1 tuần trước'
      },
    ];

    return Column(
      children: reviews.map((r) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.surfaceVariant,
                    child: Text(
                      (r['name'] as String).substring(0, 2),
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['name'] as String,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        Row(
                          children: [
                            ...List.generate(
                                r['rating'] as int,
                                (_) => const Icon(Icons.star,
                                    size: 12, color: Color(0xFFF39C12))),
                            const SizedBox(width: 6),
                            Text(r['time'] as String,
                                style: const TextStyle(
                                    color: AppColors.textHint, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Text(r['text'] as String,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4)),
              ),
              if (r != reviews.last)
                const Divider(height: 16, color: AppColors.divider),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildScheduleSection() {
    final days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final available = [true, true, false, true, true, true, false];

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

  Widget _buildBottomBar(BuildContext context) {
    final caregiver = MockData.caregivers.firstWhere(
      (c) => c.id == id,
      orElse: () => MockData.caregivers.first,
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Giá thuê',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                Text(
                  '${caregiver.hourlyRate.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}đ/giờ',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: caregiver.isAvailable
                  ? () => context.push('/booking/new')
                  : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                caregiver.isAvailable ? 'Đặt lịch ngay' : 'Hiện đang bận',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
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
