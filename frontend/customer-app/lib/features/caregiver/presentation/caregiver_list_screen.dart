import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/presentation/widgets/fade_slide_staggered.dart';
import '../application/caregiver_store.dart';
import '../data/models/caregiver_model.dart';

class CaregiverListScreen extends ConsumerStatefulWidget {
  const CaregiverListScreen({super.key});

  @override
  ConsumerState<CaregiverListScreen> createState() =>
      _CaregiverListScreenState();
}

class _CaregiverListScreenState extends ConsumerState<CaregiverListScreen> {
  bool _showAvailableOnly = false;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  List<CaregiverModel> _filtered(List<CaregiverModel> all) {
    var list = all;
    if (_showAvailableOnly) {
      list = list.where((c) => c.isOnline).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((c) =>
              c.displayName.toLowerCase().contains(q) ||
              c.skills.any((s) => s.toLowerCase().contains(q)) ||
              (c.location.toLowerCase().contains(q)))
          .toList();
    }
    return list;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caregiverAsync = ref.watch(caregiverStoreProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: caregiverAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (allCaregivers) {
          final filtered = _filtered(allCaregivers);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Flat header ──
              Container(
                color: Colors.white,
                padding: EdgeInsets.only(
                  top: topPadding + 16,
                  left: 20,
                  right: 16,
                  bottom: 0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Đội ngũ Caregiver',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${allCaregivers.length} sẵn sàng',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 13, color: AppColors.textSecondary),
                              SizedBox(width: 2),
                              Text(
                                'Hồ Chí Minh (Q.1, Q.3, Bình Thạnh)',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/notifications'),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: AppColors.background,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.notifications_outlined,
                                color: AppColors.textSecondary, size: 22),
                          ),
                          const Positioned(
                            right: 6,
                            top: 6,
                            child: CircleAvatar(
                              radius: 4,
                              backgroundColor: Color(0xFFE74C3C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Search + chips ──
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  children: [
                    // Search
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Tìm theo tên hoặc Quận/Huyện...',
                        prefixIcon: const Icon(Icons.search,
                            color: AppColors.textSecondary, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    size: 18, color: AppColors.textHint),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        hintStyle: const TextStyle(
                            color: AppColors.textHint, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: '📍 Gần tôi nhất',
                            isActive: true,
                            onTap: () {},
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: '⭐ Đánh giá 4.9+',
                            isActive: false,
                            onTap: () {},
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: '🏥 Có chứng chỉ',
                            isActive: false,
                            onTap: () {},
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: '💰 Giá ưu đãi',
                            isActive: _showAvailableOnly,
                            onTap: () => setState(
                                () => _showAvailableOnly = !_showAvailableOnly),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE8F2EC)),

              // ── List ──
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🔍', style: TextStyle(fontSize: 40)),
                            SizedBox(height: 12),
                            Text(
                              'Không tìm thấy người chăm sóc phù hợp',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: filtered.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildTrustBanner(),
                            );
                          }
                          final i = index - 1;
                          return FadeSlideStaggered(
                            index: i,
                            child: _buildCaregiverCard(filtered[i], context),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTrustBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD580), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF0C0),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user_outlined,
                color: Color(0xFFF5A623), size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'An tâm tuyệt đối với CareSitter',
                      style: TextStyle(
                        color: Color(0xFF7A4800),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'PHI Y TẾ',
                      style: TextStyle(
                        color: Color(0xFFF5A623),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  '100% Caregiver xác minh lý lịch tư pháp & đào tạo kỹ năng phi y tế.',
                  style: TextStyle(
                    color: Color(0xFFA07020),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaregiverCard(CaregiverModel caregiver, BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/caregivers/${caregiver.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: Avatar + Info ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primaryContainer,
                      child: Text(
                        caregiver.initials,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (caregiver.isOnline)
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              caregiver.displayName,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          const Icon(Icons.verified_rounded,
                              color: AppColors.primary, size: 16),
                          const SizedBox(width: 4),
                          const Icon(Icons.favorite_border_rounded,
                              color: AppColors.textHint, size: 20),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Color(0xFFF5A623), size: 14),
                          const SizedBox(width: 3),
                          Text(
                            caregiver.ratingAvg.toStringAsFixed(1),
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '  (${caregiver.ratingCount})',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                          if (caregiver.yearsOfExperience != null) ...[
                            const Text('  △  ',
                                style: TextStyle(
                                    color: AppColors.textHint, fontSize: 11)),
                            Text(
                              '${caregiver.yearsOfExperience} năm kinh nghiệm',
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                      if (caregiver.yearsOfExperience != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '📖 ${caregiver.yearsOfExperience} năm chăm sóc người lớn tuổi',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Skills ──
            if (caregiver.skills.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: caregiver.skills.take(3).map((skill) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      skill,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE8F2EC)),
            const SizedBox(height: 12),

            // ── Price + Action buttons ──
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Giá dịch vụ',
                        style:
                            TextStyle(color: AppColors.textHint, fontSize: 11),
                      ),
                      Text(
                        caregiver.hourlyRateExpected != null
                            ? '${_formatCurrency(caregiver.hourlyRateExpected!.toDouble())}/giờ'
                            : 'Liên hệ',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => context.push('/caregivers/${caregiver.id}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Xem hồ sơ',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () =>
                      context.push('/booking/new?caregiverId=${caregiver.id}'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  label: const Text('Đặt ngay'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    minimumSize: Size.zero,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    final formatted = amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return '$formattedđ';
  }
}

// ── Filter Chip Widget ────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
