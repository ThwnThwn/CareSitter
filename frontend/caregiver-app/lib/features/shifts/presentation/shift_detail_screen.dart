import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/shift_model.dart';
import 'providers/shifts_provider.dart';
import '../../earnings/presentation/providers/earnings_provider.dart';

class ShiftDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const ShiftDetailScreen({super.key, required this.id});

  @override
  ConsumerState<ShiftDetailScreen> createState() => _ShiftDetailScreenState();
}

class _ShiftDetailScreenState extends ConsumerState<ShiftDetailScreen> {
  bool _safetyExpanded = false;

  @override
  Widget build(BuildContext context) {
    final shifts = ref.watch(shiftsProvider);

    ShiftModel? booking;
    for (final b in shifts) {
      if (b.id == widget.id) {
        booking = b;
        break;
  }
}
    if (booking == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text(
            'Chi tiết Ca',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
          leading: const AppBackButton(fallbackRoute: '/shifts'),
        ),
        body: const AppEmptyState(
          icon: Icons.search_off_rounded,
          title: 'Không tìm thấy ca làm việc',
          message: 'Ca này có thể đã bị huỷ hoặc không còn tồn tại.',
        ),
      );
    }

    final beneficiary = _resolveBeneficiary(booking);
    final isPending = booking.status == 'pending' || booking.status == 'open';
    final isUpcoming =
        booking.status == 'confirmed' || booking.status == 'assigned';
    final isEnRoute = booking.status == 'caregiver_en_route';
    final isInProgress = booking.status == 'in_progress';
    final isCompleted = booking.status == 'completed';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.border,
        title: const Text(
          'Chi tiết Ca',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
        ),
        leading: const AppBackButton(fallbackRoute: '/shifts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusBanner(booking),
                  const SizedBox(height: 12),
                  _buildEarningsSummaryCard(booking),
                  const SizedBox(height: 12),
                  _buildScheduleInfo(booking),
                  const SizedBox(height: 16),
                  _buildSectionHeader('Người được chăm sóc'),
                  const SizedBox(height: 8),
                  _buildCareRecipientCard(beneficiary, booking),
                  const SizedBox(height: 16),
                  _buildSectionHeader('Địa điểm làm việc'),
                  const SizedBox(height: 8),
                  _buildLocationCard(context, booking),
                  const SizedBox(height: 16),
                  _buildSectionHeader('Công việc cần làm'),
                  const SizedBox(height: 8),
                  _buildChecklistCard(booking, beneficiary),
                  const SizedBox(height: 16),
                  _buildSafetyGuidelinesCard(beneficiary),
                  const SizedBox(height: 16),
                  if (isPending)
                    _buildAcceptRejectButtons(context, ref, booking.id),
                  if (isEnRoute) _buildEnRouteBanner(context, ref, booking),
                  if (isInProgress)
                    _buildGoToActiveShiftButton(context, booking.id),
                  if (isCompleted) _buildCompletedShiftCard(booking),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          if (isUpcoming) _buildStickyBottomBar(context, ref, booking),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  ShiftBeneficiaryModel _resolveBeneficiary(ShiftModel booking) {
    final name = booking.beneficiaryName.trim().isNotEmpty
        ? booking.beneficiaryName.trim()
        : 'Người thân';
    final initial = _getInitial(name);
    final age = booking.beneficiaryAge ?? 0;
    final relation = booking.beneficiaryRelationship?.isNotEmpty == true
        ? booking.beneficiaryRelationship!
        : 'Chưa cập nhật';
    final condition = booking.beneficiaryCondition?.isNotEmpty == true
        ? booking.beneficiaryCondition!
        : (booking.customerNote?.isNotEmpty == true
            ? booking.customerNote!
            : 'Chưa có thông tin');
    final notes = booking.beneficiaryNotes?.isNotEmpty == true
        ? booking.beneficiaryNotes!
        : (booking.customerNote?.isNotEmpty == true
            ? booking.customerNote!
            : 'Chưa có ghi chú');

    return ShiftBeneficiaryModel(
      id: booking.beneficiaryId ?? 'b_${booking.id}',
      name: name,
      age: age,
      relation: relation,
      avatarInitial: initial,
      condition: condition,
      careLevel: 'Chưa cập nhật',
      notes: notes,
    );
  }

  String _getInitial(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'N';
    return parts.first.substring(0, 1).toUpperCase();
  }

  // ─── UI Builders ──────────────────────────────────────────────────────────

  Widget _buildStatusBanner(ShiftModel booking) {
    final info = _getStatusInfo(booking.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: info.bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: info.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(info.icon, color: info.color, size: 16),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: info.color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              info.label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              info.subtitle,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  ({String label, String subtitle, Color color, Color bgColor, IconData icon})
      _getStatusInfo(String status) {
    switch (status) {
      case 'confirmed':
      case 'assigned':
        return (
          label: 'Đã xác nhận',
          subtitle: 'Sắp tới ca làm việc của bạn',
          color: AppColors.statusConfirmed,
          bgColor: AppColors.statusConfirmedBg,
          icon: Icons.check_circle_outline_rounded
        );
      case 'pending':
      case 'open':
        return (
          label: 'Chờ phản hồi',
          subtitle: 'Vui lòng nhận hoặc từ chối ca này',
          color: AppColors.statusPending,
          bgColor: AppColors.statusPendingBg,
          icon: Icons.schedule_rounded
        );
      case 'caregiver_en_route':
        return (
          label: 'Đang di chuyển',
          subtitle: 'Khách hàng theo dõi vị trí của bạn',
          color: const Color(0xFFE67E22),
          bgColor: const Color(0xFFFFF3E0),
          icon: Icons.directions_car_rounded
        );
      case 'in_progress':
        return (
          label: 'Đang diễn ra',
          subtitle: 'Ca chăm sóc đang tiến hành',
          color: AppColors.statusInProgress,
          bgColor: AppColors.statusInProgressBg,
          icon: Icons.play_circle_outline_rounded
        );
      case 'completed':
        return (
          label: 'Hoàn thành',
          subtitle: 'Ca đã hoàn tất thành công',
          color: AppColors.statusCompleted,
          bgColor: AppColors.statusCompletedBg,
          icon: Icons.check_circle_rounded
        );
      default:
        return (
          label: 'Không xác định',
          subtitle: '',
          color: AppColors.textHint,
          bgColor: AppColors.surfaceVariant,
          icon: Icons.help_outline_rounded
        );
    }
  }

  Widget _buildEarningsSummaryCard(ShiftModel booking) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatCurrency(booking.caregiverEarning)}đ',
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary),
                ),
                const SizedBox(height: 2),
                const Text('Thu nhập dự kiến',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
              width: 1,
              height: 40,
              color: AppColors.border,
              margin: const EdgeInsets.symmetric(horizontal: 16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.duration,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                const Text('Thời lượng',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleInfo(ShiftModel booking) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(booking.date,
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500)),
          ),
          Container(
              width: 1,
              height: 18,
              color: AppColors.border,
              margin: const EdgeInsets.symmetric(horizontal: 12)),
          const Icon(Icons.access_time_rounded,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(booking.time,
              style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary),
    );
  }

  Widget _buildCareRecipientCard(
      ShiftBeneficiaryModel beneficiary, ShiftModel booking) {
    final displayAge = booking.beneficiaryAge ?? beneficiary.age;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  beneficiary.avatarInitial,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(beneficiary.name,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      displayAge > 0
                          ? '$displayAge tuổi • ${booking.serviceName}'
                          : booking.serviceName,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (beneficiary.condition.isNotEmpty &&
              beneficiary.condition != 'Chưa có thông tin') ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 15, color: AppColors.textHint),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    beneficiary.condition,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.phone_rounded,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Liên hệ khẩn cấp: ${beneficiary.relation}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Gọi',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(BuildContext context, ShiftModel booking) {
    final destination = _destinationFor(booking);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15), topRight: Radius.circular(15)),
            child: destination == null
                ? _buildMapUnavailablePreview()
                : _buildMapPreview(context, booking, destination),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(booking.address,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              height: 1.4)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _openMap(context, booking),
                  child: const Row(
                    children: [
                      Icon(Icons.directions_rounded,
                          size: 16, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text('Xem chỉ đường trên bản đồ',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                      Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  LatLng? _destinationFor(ShiftModel booking) {
    final latitude = booking.addressLatitude;
    final longitude = booking.addressLongitude;
    if (latitude == null ||
        longitude == null ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return null;
    }
    return LatLng(latitude, longitude);
  }

  void _openMap(BuildContext context, ShiftModel booking) {
    context.push('/shifts/${booking.id}/map', extra: {
      'beneficiaryName': booking.beneficiaryName,
      'address': booking.address,
      'addressLatitude': booking.addressLatitude,
      'addressLongitude': booking.addressLongitude,
    });
  }

  Widget _buildMapPreview(
    BuildContext context,
    ShiftModel booking,
    LatLng destination,
  ) {
    return SizedBox(
      height: 170,
      width: double.infinity,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: destination,
              initialZoom: 16,
              interactionOptions:
                  const InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                retinaMode: true,
                userAgentPackageName: 'com.caresitter.caregiver',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: destination,
                    width: 56,
                    height: 68,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.45),
                                blurRadius: 16,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.home_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 10,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on_rounded,
                      size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    'Địa điểm khách hàng',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openMap(context, booking),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapUnavailablePreview() {
    return Container(
      height: 128,
      width: double.infinity,
      color: AppColors.surfaceVariant,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined,
                color: AppColors.textHint, size: 26),
            SizedBox(height: 6),
            Text(
              'Chưa có tọa độ để hiển thị bản đồ',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistCard(
      ShiftModel booking, ShiftBeneficiaryModel beneficiary) {
    final hasTasks = booking.tasks.isNotEmpty;
    final completedCount =
        hasTasks ? booking.tasks.where((t) => t.isCompleted).length : 0;
    final total = hasTasks ? booking.tasks.length : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTasks) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? completedCount / total : 0,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('$completedCount/$total hoàn thành',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (!hasTasks)
            const Text('Không có checklist công việc đặc biệt.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary))
          else
            ...booking.tasks.map((task) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        task.isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: task.isCompleted
                            ? AppColors.primary
                            : AppColors.textHint,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 14,
                            color: task.isCompleted
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          if (beneficiary.notes.isNotEmpty &&
              beneficiary.notes != 'Chưa có ghi chú') ...[
            const Divider(height: 20, color: AppColors.border),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.sticky_note_2_outlined,
                    size: 15, color: AppColors.textHint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(beneficiary.notes,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSafetyGuidelinesCard(ShiftBeneficiaryModel beneficiary) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _safetyExpanded = !_safetyExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.health_and_safety_outlined,
                        size: 18, color: Color(0xFFE67E22)),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Quy tắc An toàn Phi Y tế',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ),
                  Icon(
                    _safetyExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_safetyExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 12),
                  _safetyItem(
                      'Không tự ý cho khách dùng thuốc ngoài danh sách được giao'),
                  _safetyItem(
                      'Không di chuyển khách ra ngoài khu vực đã được phê duyệt'),
                  _safetyItem(
                      'Báo cáo ngay nếu phát hiện triệu chứng bất thường'),
                  _safetyItem('Tuân thủ quy trình check-in / check-out GPS'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _safetyItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 5, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4))),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar(
      BuildContext context, WidgetRef ref, ShiftModel booking) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () async {
            try {
              await ref.read(shiftsProvider.notifier).startEnRoute(booking.id);
              if (!context.mounted) return;
              AppToast.success(
                  context, '🚗 Bắt đầu di chuyển! Khách hàng theo dõi vị trí của bạn.');
            } catch (error) {
              if (!context.mounted) return;
              AppToast.error(context, 'Chưa thể bắt đầu di chuyển: $error');
            }
          },
          icon: const Icon(Icons.directions_car_rounded,
              color: Colors.white, size: 20),
          label: const Text(
            'Bắt đầu di chuyển đến điểm hẹn',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  // ─── Status-specific action widgets ───────────────────────────────────────

  Widget _buildAcceptRejectButtons(
      BuildContext context, WidgetRef ref, String bookingId) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Từ chối ca?'),
                  content: const Text(
                      'Bạn có chắc muốn từ chối ca làm việc này không?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Không')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.error),
                        child: const Text('Từ chối')),
                  ],
                ),
              );
              if (confirmed != true) return;
              try {
                await ref
                    .read(shiftsProvider.notifier)
                    .declineBooking(bookingId);
                if (context.mounted) {
                  context.pop();
                  AppToast.success(context, 'Đã từ chối ca làm việc này.');
                }
              } catch (e) {
                if (context.mounted) {
                  AppToast.error(context, 'Chưa từ chối được ca: $e');
                }
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Từ chối',
                style: TextStyle(color: AppColors.textPrimary)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () async {
              try {
                await ref
                    .read(shiftsProvider.notifier)
                    .acceptBooking(bookingId);
                if (context.mounted) {
                  context.pop();
                  AppToast.success(
                      context, '✅ Đã nhận ca thành công! Ca nằm trong Tab Sắp tới.');
                }
              } catch (e) {
                if (context.mounted) {
                  AppToast.error(context, 'Lỗi nhận ca: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Nhận ca',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildEnRouteBanner(
      BuildContext context, WidgetRef ref, ShiftModel booking) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFE67E22).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.navigation_rounded,
                  color: Color(0xFFE67E22), size: 20),
              SizedBox(width: 8),
              Text('Đang trên đường đến',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE67E22))),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Khách hàng đang theo dõi vị trí của bạn.\nHãy check-in khi đến nơi trong bán kính quy định.',
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  await ref.read(shiftsProvider.notifier).checkIn(booking.id);
                } catch (error) {
                  if (!context.mounted) return;
                  AppToast.error(context, 'Check-in chưa thành công: $error');
                  return;
                }
                if (!context.mounted) return;
                context.pushReplacement('/shifts/${booking.id}/active');
                AppToast.success(
                    context, '📍 Đã GPS check-in! Bắt đầu thực hiện ca chăm sóc.');
              },
              icon: const Icon(Icons.my_location_rounded,
                  size: 18, color: Colors.white),
              label: const Text('GPS Check-in tại địa điểm',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoToActiveShiftButton(BuildContext context, String bookingId) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => context.pushReplacement('/shifts/$bookingId/active'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppColors.primary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Vào ca đang diễn ra',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ),
    );
  }

  Widget _buildCompletedShiftCard(ShiftModel booking) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.statusCompletedBg,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.statusCompleted.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded,
                  color: AppColors.statusCompleted, size: 22),
              SizedBox(width: 8),
              Text('Ca làm việc đã hoàn thành',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.statusCompleted)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Thu nhập của bạn:',
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              Text(
                '+ ${formatCurrency(booking.caregiverEarning)}đ',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.statusCompleted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
