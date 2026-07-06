import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class ShiftCustomerReportScreen extends StatefulWidget {
  final String bookingId;
  final String beneficiaryName;
  final String caregiverName;
  final double caregiverEarning;
  final int completedTasks;
  final int totalTasks;
  final String duration;
  final String checkInTime;
  final String caregiverNote;
  final List<String> taskPhotos; // task titles that have photos

  const ShiftCustomerReportScreen({
    super.key,
    required this.bookingId,
    required this.beneficiaryName,
    required this.caregiverName,
    required this.caregiverEarning,
    required this.completedTasks,
    required this.totalTasks,
    required this.duration,
    this.checkInTime = '08:05',
    this.caregiverNote = '',
    this.taskPhotos = const [],
  });

  @override
  State<ShiftCustomerReportScreen> createState() =>
      _ShiftCustomerReportScreenState();
}

class _ShiftCustomerReportScreenState
    extends State<ShiftCustomerReportScreen> {
  int _starRating = 0;
  bool _ratingSubmitted = false;

  // Mocked task names for demo
  static const _demoTasks = [
    'Hỗ trợ vệ sinh cá nhân',
    'Cho ăn sáng và uống thuốc',
    'Tập thể dục nhẹ',
    'Dọn dẹp phòng',
    'Đọc sách / trò chuyện',
  ];

  // Mocked evidence photos for demo (gradient placeholder)
  static const _photoColors = [
    [Color(0xFF2F7F7F), Color(0xFF3A8D8C)],
    [Color(0xFFF39C12), Color(0xFFE67E22)],
    [Color(0xFF2ECC71), Color(0xFF27AE60)],
    [Color(0xFF3498DB), Color(0xFF2980B9)],
  ];

  String _formatCurrency(double amount) {
    final str = amount.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return buf.toString();
  }

  // Compute check-out time from check-in + duration
  String get _checkOutTime {
    final parts = widget.checkInTime.split(':');
    if (parts.length != 2) return '--:--';
    final h = int.tryParse(parts[0]) ?? 8;
    final m = int.tryParse(parts[1]) ?? 0;
    final durHours = int.tryParse(widget.duration.replaceAll(RegExp(r'[^0-9]'), '')) ?? 2;
    final total = h * 60 + m + durHours * 60;
    return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                _buildCaregiverCard(),
                const SizedBox(height: 20),
                _buildTimeline(),
                const SizedBox(height: 20),
                _buildChecklistSection(),
                const SizedBox(height: 20),
                _buildPhotoGallery(),
                if (widget.caregiverNote.trim().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildNoteCard(),
                ],
                const SizedBox(height: 20),
                _buildRatingSection(),
                const SizedBox(height: 28),
                _buildShareButton(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sliver AppBar ────────────────────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        'Báo cáo khách hàng',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.heroGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Chăm sóc ${widget.beneficiaryName}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ca #${widget.bookingId} • ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Caregiver card ───────────────────────────────────────
  Widget _buildCaregiverCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                widget.caregiverName.isNotEmpty
                    ? widget.caregiverName[0].toUpperCase()
                    : 'C',
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.caregiverName,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '✅ Đã xác minh',
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    ...List.generate(
                        5,
                        (i) => Icon(
                              i < 4
                                  ? Icons.star_rounded
                                  : Icons.star_half_rounded,
                              size: 14,
                              color: AppColors.secondary,
                            )),
                    const SizedBox(width: 4),
                    const Text('4.9 • 128 đánh giá',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          // Earning
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Chi phí',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              Text(
                '${_formatCurrency(widget.caregiverEarning)} đ',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Timeline check-in / check-out ───────────────────────
  Widget _buildTimeline() {
    return _buildSection(
      title: '⏱ Thời gian ca làm việc',
      child: Row(
        children: [
          _buildTimePoint(
            label: 'Check-in',
            time: widget.checkInTime,
            icon: Icons.login_rounded,
            color: AppColors.primary,
          ),
          Expanded(
            child: Column(
              children: [
                Container(height: 2, color: AppColors.border),
                const SizedBox(height: 4),
                Text(
                  widget.duration,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          _buildTimePoint(
            label: 'Check-out',
            time: _checkOutTime,
            icon: Icons.logout_rounded,
            color: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildTimePoint({
    required String label,
    required String time,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          time,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color),
        ),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  // ─── Checklist ───────────────────────────────────────────
  Widget _buildChecklistSection() {
    final tasks = widget.completedTasks > 0
        ? _demoTasks.take(widget.totalTasks > 0 ? widget.totalTasks : 3).toList()
        : _demoTasks.take(3).toList();

    return _buildSection(
      title: '✅ Checklist công việc',
      subtitle: '${widget.completedTasks}/${tasks.length} hoàn thành',
      child: Column(
        children: tasks.asMap().entries.map((e) {
          final i = e.key;
          final title = e.value;
          final done = i < widget.completedTasks;
          final hasPhoto = widget.taskPhotos.contains(title);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: done
                  ? AppColors.success.withValues(alpha: 0.05)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: done
                    ? AppColors.success.withValues(alpha: 0.25)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: done ? AppColors.success : AppColors.textHint,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: done
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (hasPhoto || done)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image_rounded,
                            size: 11, color: AppColors.primary),
                        SizedBox(width: 3),
                        Text('Có ảnh',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Photo gallery ────────────────────────────────────────
  Widget _buildPhotoGallery() {
    return _buildSection(
      title: '📷 Ảnh minh chứng',
      subtitle: '${_photoColors.length} ảnh',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.3,
        ),
        itemCount: _photoColors.length,
        itemBuilder: (ctx, i) {
          final photoLabels = [
            'Check-in selfie',
            'Bữa ăn sáng',
            'Tập thể dục',
            'Phòng sau dọn',
          ];
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _photoColors[i],
                    ),
                  ),
                ),
                // Overlay icon
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        i == 0
                            ? Icons.face_rounded
                            : i == 1
                                ? Icons.restaurant_rounded
                                : i == 2
                                    ? Icons.fitness_center_rounded
                                    : Icons.cleaning_services_rounded,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 28,
                      ),
                    ],
                  ),
                ),
                // Label bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                    child: Text(
                      photoLabels[i],
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                // Timestamp top-right
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(8 + i).toString().padLeft(2, '0')}:${(5 + i * 12).toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Caregiver note ───────────────────────────────────────
  Widget _buildNoteCard() {
    return _buildSection(
      title: '📝 Ghi chú từ người chăm sóc',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          widget.caregiverNote.trim().isNotEmpty
              ? widget.caregiverNote
              : 'Bé ăn được 1 bát cháo thịt. Uống đủ thuốc buổi sáng. Ngủ trưa khoảng 45 phút. Tinh thần vui vẻ, nói chuyện nhiều.',
          style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5),
        ),
      ),
    );
  }

  // ─── Rating section ───────────────────────────────────────
  Widget _buildRatingSection() {
    return _buildSection(
      title: '⭐ Đánh giá người chăm sóc',
      child: _ratingSubmitted
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success),
                  const SizedBox(width: 8),
                  Text(
                    'Cảm ơn! Bạn đã đánh giá $_starRating ⭐',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                const Text(
                  'Bạn hài lòng với dịch vụ hôm nay không?',
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (i) => GestureDetector(
                      onTap: () => setState(() => _starRating = i + 1),
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            i < _starRating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            key: ValueKey('$i-${_starRating > i}'),
                            size: 40,
                            color: i < _starRating
                                ? AppColors.secondary
                                : AppColors.border,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _starRating > 0
                        ? () => setState(() => _ratingSubmitted = true)
                        : null,
                    child: const Text('Gửi đánh giá'),
                  ),
                ),
              ],
            ),
    );
  }

  // ─── Share button ─────────────────────────────────────────
  Widget _buildShareButton() {
    return OutlinedButton.icon(
      icon: const Icon(Icons.share_rounded),
      label: const Text('Chia sẻ báo cáo'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        foregroundColor: AppColors.primary,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('📤 Đã sao chép link báo cáo'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }

  // ─── Section wrapper ──────────────────────────────────────
  Widget _buildSection({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              if (subtitle != null) ...[
                const Spacer(),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
