import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/loading_list.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import 'package:caresitter_customer/features/caregiver/presentation/controllers/nearby_caregiver_controller.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_location_selector.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';
import 'package:caresitter_customer/features/home/presentation/controllers/notifications_controller.dart';

class CaregiverListScreen extends ConsumerStatefulWidget {
  const CaregiverListScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<CaregiverListScreen> createState() =>
      _CaregiverListScreenState();
}

class _CaregiverListScreenState extends ConsumerState<CaregiverListScreen> {
  bool _showAvailableOnly = false;
  late final TextEditingController _searchCtrl;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialQuery?.trim() ?? '';
    _searchCtrl = TextEditingController(text: _searchQuery);
  }

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
    final caregiverAsync = ref.watch(nearbyCaregiversProvider);
    final hasLocation =
        ref.watch(caregiverSearchAddressProvider).valueOrNull != null;
    final topPadding = MediaQuery.of(context).padding.top;
    final unreadCount = ref
            .watch(notificationsProvider)
            .valueOrNull
            ?.where((notification) => !notification.isRead)
            .length ??
        0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: caregiverAsync.when(
        skipLoadingOnRefresh: false,
        loading: () => const SafeArea(
            child: Column(children: [
          Padding(
              padding: EdgeInsets.all(16), child: CaregiverLocationSelector()),
          Expanded(child: LoadingList()),
        ])),
        error: (e, _) => Center(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
                padding: EdgeInsets.all(16),
                child: CaregiverLocationSelector()),
            const Text('Chưa tải được danh sách chăm sóc viên.'),
            TextButton(
                onPressed: () => ref.invalidate(nearbyCaregiversProvider),
                child: const Text('Thử lại')),
          ],
        )),
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'Đội ngũ Chăm sóc viên',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  hasLocation
                                      ? '${allCaregivers.length} trong khu vực'
                                      : 'Chưa chọn địa chỉ',
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
                          if (unreadCount > 0)
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
                    const CaregiverLocationSelector(),
                    const SizedBox(height: 12),
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
                            label: 'Tất cả trong khu vực',
                            isActive: !_showAvailableOnly,
                            onTap: () =>
                                setState(() => _showAvailableOnly = false),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Đang trực tuyến',
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
              const Divider(height: 1, color: AppColors.divider),

              // ── List ──
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasLocation
                                  ? Icons.search
                                  : Icons.location_on_outlined,
                              size: 40,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              !hasLocation
                                  ? 'Chọn địa chỉ chăm sóc để xem người ở gần.'
                                  : allCaregivers.isEmpty
                                      ? 'Chưa có chăm sóc viên phục vụ địa chỉ này.\nThử đổi địa chỉ chăm sóc.'
                                      : 'Không có chăm sóc viên khớp bộ lọc.\nThử đổi từ khóa hoặc trạng thái trực tuyến.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        key: const PageStorageKey('caregiver-list'),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return FadeSlideStaggered(
                            key: ValueKey(filtered[index].id),
                            index: index,
                            child:
                                _buildCaregiverCard(filtered[index], context),
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
                    Hero(
                      tag: 'caregiver-avatar-${caregiver.id}',
                      child: CircleAvatar(
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
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: AppColors.secondary, size: 14),
                              const SizedBox(width: 3),
                              Text(
                                caregiver.ratingAvg.toStringAsFixed(1),
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                              Text(
                                ' (${caregiver.ratingCount})',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                          if (caregiver.yearsOfExperience != null) ...[
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
            if (caregiver.distanceLabel != null) ...[
              const SizedBox(height: 10),
              Text('Khoảng ${caregiver.distanceLabel} từ địa chỉ chăm sóc',
                  style:
                      const TextStyle(color: AppColors.primary, fontSize: 12)),
            ],
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
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),

            // ── Price + Action buttons ──
            LayoutBuilder(builder: (context, constraints) {
              final price = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Giá dịch vụ',
                    style: TextStyle(color: AppColors.textHint, fontSize: 11),
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
              );
              final actions = <Widget>[
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
              ];
              final textScale = MediaQuery.textScalerOf(context).scale(13) / 13;
              if (constraints.maxWidth < 360 * textScale) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    price,
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: actions),
                  ],
                );
              }
              return Row(children: [
                Expanded(child: price),
                actions[0],
                const SizedBox(width: 8),
                actions[1],
              ]);
            }),
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
