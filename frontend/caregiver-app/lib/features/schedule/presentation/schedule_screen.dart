import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/shift_status_style.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../shifts/presentation/providers/shifts_provider.dart';
import 'providers/schedule_provider.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  late DateTime _selectedDate;
  late DateTime _weekStart;
  late ScrollController _timelineScrollController;
  bool _isMonthView = false; // toggle: week strip vs full month grid

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _weekStart = _getWeekStart(_selectedDate);
    _timelineScrollController = ScrollController();
    // Auto-scroll to current hour after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentHour();
    });
  }

  @override
  void dispose() {
    _timelineScrollController.dispose();
    super.dispose();
  }

  DateTime _getWeekStart(DateTime date) {
    final diff = date.weekday - 1; // Monday = 1
    return DateTime(date.year, date.month, date.day - diff);
  }

  void _scrollToCurrentHour() {
    final now = DateTime.now();
    final targetOffset = now.hour.clamp(0, 23) * 80.0;
    if (_timelineScrollController.hasClients) {
      _timelineScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _previousPeriod() {
    setState(() {
      if (_isMonthView) {
        // Move to previous month
        final first = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
        _selectedDate = first;
        _weekStart = _getWeekStart(first);
      } else {
        _weekStart = _weekStart.subtract(const Duration(days: 7));
        _selectedDate = _weekStart;
      }
    });
  }

  void _nextPeriod() {
    setState(() {
      if (_isMonthView) {
        // Move to next month
        final first = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
        _selectedDate = first;
        _weekStart = _getWeekStart(first);
      } else {
        _weekStart = _weekStart.add(const Duration(days: 7));
        _selectedDate = _weekStart;
      }
    });
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
    _scrollToCurrentHour();
  }

  String _getMonthName(int month) {
    const months = [
      'Tháng 1',
      'Tháng 2',
      'Tháng 3',
      'Tháng 4',
      'Tháng 5',
      'Tháng 6',
      'Tháng 7',
      'Tháng 8',
      'Tháng 9',
      'Tháng 10',
      'Tháng 11',
      'Tháng 12',
    ];
    return months[month - 1];
  }

  String _getDayOfWeekName(int weekday) {
    const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return days[weekday - 1];
  }

  String _getFullDayOfWeekName(int weekday) {
    const days = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    return days[weekday - 1];
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(scheduleProvider);
    final shifts = ref.watch(shiftsProvider);

    // Get available slots for selected date
    final daySlots =
        ref.read(scheduleProvider.notifier).getSlotsForDate(_selectedDate);

    // Get booked shifts for the selected date (parse time range from shifts)
    final dayShifts = _getShiftsForDate(shifts);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Top Header with month, day, and nav ──
          _buildHeader(),
          // ── Date Selector Row ──
          _buildDateSelector(),
          const SizedBox(height: 4),
          // ── Timeline Body ──
          Expanded(
            child: _buildTimeline(daySlots, dayShifts),
          ),
        ],
      ),
    );
  }

  List<TimelineShift> _getShiftsForDate(List shifts) {
    final List<TimelineShift> result = [];
    for (final booking in shifts) {
      // Lọc đúng ngày được chọn dựa trên scheduledStart (DateTime thật từ API).
      // Fallback sang parse chuỗi date nếu scheduledStart chưa có.
      final matchesDate = _bookingMatchesDate(booking, _selectedDate);
      if (!matchesDate) continue;

      // Parse the time field "08:00 - 12:00"
      final timeParts = booking.time.split(' - ');
      if (timeParts.length == 2) {
        final startHour = int.tryParse(timeParts[0].split(':')[0]) ?? 0;
        final endHour = int.tryParse(timeParts[1].split(':')[0]) ?? 0;

        if (booking.status == 'confirmed' ||
            booking.status == 'assigned' ||
            booking.status == 'in_progress' ||
            booking.status == 'caregiver_en_route' ||
            booking.status == 'pending') {
          result.add(TimelineShift(
            id: booking.id,
            beneficiaryName: booking.beneficiaryName,
            serviceName: booking.serviceName,
            status: booking.status,
            startHour: startHour,
            endHour: endHour,
            duration: booking.duration,
            address: booking.address,
          ));
        }
      }
    }
    return result;
  }

  /// So sánh booking với ngày được chọn.
  /// Ưu tiên scheduledStart (DateTime thật), fallback sang parse chuỗi date "dd/MM/yyyy".
  bool _bookingMatchesDate(dynamic booking, DateTime date) {
    final start = booking.scheduledStart as DateTime?;
    if (start != null) {
      return start.year == date.year &&
          start.month == date.month &&
          start.day == date.day;
    }
    // Fallback: parse "dd/MM/yyyy" từ booking.date
    final parts = (booking.date as String).split('/');
    if (parts.length == 3) {
      final d = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (d != null && m != null && y != null) {
        return d == date.day && m == date.month && y == date.year;
      }
    }
    return false;
  }

  // ────────────────────────────────────────────────────────────────
  // HEADER — styled like the reference image (month + big day number)
  // ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 24,
        right: 16,
        bottom: 16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left — Month name + Day of week + Big day number
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month + toggle chevron
                GestureDetector(
                  onTap: _pickDate,
                  child: Row(
                    children: [
                      Text(
                        _getMonthName(_selectedDate.month),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _isMonthView ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: const Icon(
                          Icons.expand_more_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (!_isMonthView)
                        Flexible(
                          child: Text(
                            _getFullDayOfWeekName(_selectedDate.weekday),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_selectedDate.day}',
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.1,
                    letterSpacing: -2,
                  ),
                ),
              ],
            ),
          ),
          // Right — Navigation arrows (week / month aware)
          Row(
            children: [
              _buildNavButton(Icons.chevron_left, _previousPeriod),
              const SizedBox(width: 4),
              _buildNavButton(Icons.chevron_right, _nextPeriod),
            ],
          ),
          const SizedBox(width: 4),
          // Mở date picker giống customer
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded,
                color: AppColors.textSecondary),
            tooltip: 'Chọn ngày',
            onPressed: _pickDate,
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 20, color: AppColors.textSecondary),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.cardBackground,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) _selectDate(picked);
  }

  // ────────────────────────────────────────────────────────────────
  // DATE SELECTOR — week strip or full month grid
  // ────────────────────────────────────────────────────────────────
  Widget _buildDateSelector() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Container(
        color: AppColors.cardBackground,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            // Month + Year label row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    '${_getMonthName(_isMonthView ? _selectedDate.month : _weekStart.month)} ${_isMonthView ? _selectedDate.year : _weekStart.year}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── Week strip or Month grid ──
            _isMonthView ? _buildMonthGrid() : _buildWeekStrip(),
          ],
        ),
      ),
    );
  }

  // ── Week strip (original 7-day horizontal list) ──
  Widget _buildWeekStrip() {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 7,
        itemBuilder: (context, index) {
          final date = _weekStart.add(Duration(days: index));
          return _buildDayCell(date, chipWidth: 48);
        },
      ),
    );
  }

  // ── Full month grid ──
  Widget _buildMonthGrid() {
    final year = _selectedDate.year;
    final month = _selectedDate.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // offset: Monday=1 → 0-indexed offset (Mon=0)
    final startOffset = (firstDay.weekday - 1) % 7;

    // Day-of-week header (T2..CN)
    const dayHeaders = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Header row
          Row(
            children: dayHeaders
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Grid cells
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 4,
              childAspectRatio: 0.9,
            ),
            itemCount: startOffset + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startOffset) {
                return const SizedBox
                    .shrink(); // empty cells before month start
              }
              final day = index - startOffset + 1;
              final date = DateTime(year, month, day);
              return _buildDayCell(date,
                  chipWidth: double.infinity, compact: true);
            },
          ),
        ],
      ),
    );
  }

  // ── Shared day cell widget ──
  Widget _buildDayCell(DateTime date,
      {double chipWidth = 48, bool compact = false}) {
    final isSelected = date.day == _selectedDate.day &&
        date.month == _selectedDate.month &&
        date.year == _selectedDate.year;
    final isCurrentDay = _isToday(date);
    final dayName = _getDayOfWeekName(date.weekday);
    final hasSlots =
        ref.read(scheduleProvider.notifier).getSlotsForDate(date).isNotEmpty;

    return GestureDetector(
      onTap: () {
        _selectDate(date);
        if (_isMonthView) {
          // Switch to week view to see timeline for chosen date
          setState(() {
            _isMonthView = false;
            _weekStart = _getWeekStart(date);
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: chipWidth == double.infinity ? null : chipWidth,
        margin: compact
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : isCurrentDay
                  ? AppColors.primaryContainer
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(compact ? 10 : 24),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : isCurrentDay
                    ? AppColors.primaryLight
                    : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: compact ? 14 : 18,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 2),
              Text(
                dayName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.85)
                      : AppColors.textSecondary,
                ),
              ),
            ],
            // Dot indicator for days with availability
            if (hasSlots && !isSelected) ...[
              SizedBox(height: compact ? 2 : 4),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // TIMELINE — vertical timeline with hour labels + shift cards
  // ────────────────────────────────────────────────────────────────
  Widget _buildTimeline(
      List<AvailabilitySlot> daySlots, List<TimelineShift> dayShifts) {
    return ListView.builder(
      controller: _timelineScrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: 24, // Hiển thị đủ 00:00 đến 23:00 trong ngày
      itemBuilder: (context, index) {
        final hour = index;
        final timeLabel = '${hour.toString().padLeft(2, '0')}:00';

        // Check if this hour falls within an availability slot
        final matchingSlot =
            daySlots.where((s) => hour >= s.startHour && hour < s.endHour);
        final isAvailable = matchingSlot.isNotEmpty;

        // Check if there's a shift starting at this hour
        final startingShift =
            dayShifts.where((s) => s.startHour == hour).toList();

        // Check if this hour is covered by a shift (for the green bar)
        final isShiftHour =
            dayShifts.any((s) => hour >= s.startHour && hour < s.endHour);

        // Current hour indicator
        final now = DateTime.now();
        final isCurrentHour = _isToday(_selectedDate) && now.hour == hour;

        return IntrinsicHeight(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 80),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hour label ──
                SizedBox(
                  width: 60,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, top: 2),
                    child: Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isCurrentHour ? FontWeight.w700 : FontWeight.w400,
                        color: isCurrentHour
                            ? AppColors.primary
                            : AppColors.textHint,
                      ),
                    ),
                  ),
                ),

                // ── Timeline line + indicators ──
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      // Dot — smaller sizes to avoid overflow
                      Container(
                        width: isCurrentHour ? 10 : 6,
                        height: isCurrentHour ? 10 : 6,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrentHour
                              ? AppColors.primary
                              : isShiftHour
                                  ? AppColors.statusConfirmed
                                  : isAvailable
                                      ? AppColors.primary.withValues(alpha: 0.3)
                                      : AppColors.border,
                          border: isCurrentHour
                              ? Border.all(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.3),
                                  width: 3)
                              : null,
                        ),
                      ),
                      // Vertical line — fills remaining space
                      Expanded(
                        child: Center(
                          child: Container(
                            width: isShiftHour ? 3 : 1.5,
                            decoration: BoxDecoration(
                              color: isShiftHour
                                  ? AppColors.statusConfirmed
                                  : isAvailable
                                      ? AppColors.primary.withValues(alpha: 0.2)
                                      : AppColors.border.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Content area (shift card or availability indicator) ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16, bottom: 8),
                    child: startingShift.isNotEmpty
                        ? _buildShiftCard(startingShift.first)
                        : isAvailable && _isSlotStart(daySlots, hour)
                            ? _buildAvailabilityIndicator(
                                matchingSlot.first, context)
                            : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isSlotStart(List<AvailabilitySlot> slots, int hour) {
    return slots.any((s) => s.startHour == hour);
  }

  // ── Shift Card (similar to the reference image appointment card) ──
  Widget _buildShiftCard(TimelineShift shift) {
    final style = ShiftStatusStyle.of(shift.status);
    final statusColor = style.color;
    final statusLabel = style.label;
    final accentColor = style.color;

    return GestureDetector(
      onTap: () {
        if (shift.status == 'in_progress') {
          context.push('/shifts/${shift.id}/active');
        } else {
          context.push('/shifts/${shift.id}');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Accent left bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            shift.beneficiaryName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        StatusBadge(
                          label: statusLabel,
                          color: statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shift.serviceName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Meta-info row: allow wrapping on narrow screens
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_rounded,
                                size: 14, color: AppColors.textHint),
                            const SizedBox(width: 4),
                            Text(
                              shift.duration,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: AppColors.textHint),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Text(
                                shift.address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Availability Indicator (teal outlined chip) ──
  Widget _buildAvailabilityIndicator(
      AvailabilitySlot slot, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Rảnh ${slot.timeLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _confirmRemoveSlot(slot),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveSlot(AvailabilitySlot slot) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa lịch rảnh?'),
        content: Text(
            'Bạn có muốn xóa khung giờ ${slot.timeLabel} khỏi lịch rảnh không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              ref.read(scheduleProvider.notifier).removeSlot(slot.id);
              Navigator.pop(ctx);
            },
            child: const Text('Xóa', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Bottom sheet for adding availability
// ══════════════════════════════════════════════════════════════════
class _AddAvailabilitySheet extends StatefulWidget {
  final DateTime selectedDate;
  final void Function(DateTime date, int startHour, int endHour) onAdd;

  const _AddAvailabilitySheet({
    required this.selectedDate,
    required this.onAdd,
  });

  @override
  State<_AddAvailabilitySheet> createState() => _AddAvailabilitySheetState();
}

class _AddAvailabilitySheetState extends State<_AddAvailabilitySheet> {
  late DateTime _sheetDate;
  late DateTime _sheetWeekStart;
  int? _selectedStartHour;
  int? _selectedEndHour;
  bool _isSelectingEnd = false;

  @override
  void initState() {
    super.initState();
    _sheetDate = widget.selectedDate;
    _sheetWeekStart = _getWeekStart(_sheetDate);
  }

  DateTime _getWeekStart(DateTime date) {
    final diff = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - diff);
  }

  String _getMonthName(int month) {
    const months = [
      'Tháng 1',
      'Tháng 2',
      'Tháng 3',
      'Tháng 4',
      'Tháng 5',
      'Tháng 6',
      'Tháng 7',
      'Tháng 8',
      'Tháng 9',
      'Tháng 10',
      'Tháng 11',
      'Tháng 12',
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chọn ngày & giờ',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Chọn thời gian bạn có thể nhận ca',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Date selector in sheet ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _pickSheetDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_getMonthName(_sheetDate.month)} ${_sheetDate.year}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.expand_more_rounded,
                            size: 18, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 64,
                  child: Row(
                    children: List.generate(7, (index) {
                      final date = _sheetWeekStart.add(Duration(days: index));
                      final isSelected = date.day == _sheetDate.day &&
                          date.month == _sheetDate.month;
                      final dayName = [
                        'T2',
                        'T3',
                        'T4',
                        'T5',
                        'T6',
                        'T7',
                        'CN'
                      ][date.weekday - 1];

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _sheetDate = date),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dayName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.8)
                                        : AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Time slots by period ──
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 18, color: AppColors.info),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isSelectingEnd
                                ? 'Chọn giờ kết thúc (sau ${_selectedStartHour!.toString().padLeft(2, '0')}:00)'
                                : 'Bước 1: Chọn giờ bắt đầu',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.info,
                            ),
                          ),
                        ),
                        if (_isSelectingEnd)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isSelectingEnd = false;
                                _selectedStartHour = null;
                              });
                            },
                            child: const Text(
                              'Đặt lại',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildTimePeriodSection(
                    'Sáng',
                    Icons.wb_sunny_outlined,
                    [6, 7, 8, 9, 10, 11],
                  ),
                  const SizedBox(height: 20),
                  _buildTimePeriodSection(
                    'Chiều',
                    Icons.wb_twilight_rounded,
                    [12, 13, 14, 15, 16, 17],
                  ),
                  const SizedBox(height: 20),
                  _buildTimePeriodSection(
                    'Tối',
                    Icons.nightlight_round,
                    [18, 19, 20, 21, 22],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ── Bottom action buttons ──
          Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              top: 16,
            ),
            decoration: const BoxDecoration(
              color: AppColors.cardBackground,
              border: Border(
                top: BorderSide(color: AppColors.divider),
              ),
            ),
            child: Row(
              children: [
                // Selected time summary
                if (_selectedStartHour != null && _selectedEndHour != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Đã chọn',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${_selectedStartHour!.toString().padLeft(2, '0')}:00 - ${_selectedEndHour!.toString().padLeft(2, '0')}:00',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Expanded(
                    child: Text(
                      'Chọn giờ bắt đầu và kết thúc',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 140,
                  child: AppButton(
                    label: 'Xác nhận',
                    icon: Icons.check_rounded,
                    onPressed:
                        (_selectedStartHour != null && _selectedEndHour != null)
                            ? () {
                                widget.onAdd(
                                  _sheetDate,
                                  _selectedStartHour!,
                                  _selectedEndHour!,
                                );
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Đã thêm lịch rảnh ${_selectedStartHour!.toString().padLeft(2, '0')}:00 - ${_selectedEndHour!.toString().padLeft(2, '0')}:00'),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSheetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _sheetDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.cardBackground,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _sheetDate = picked;
        _sheetWeekStart = _getWeekStart(picked);
      });
    }
  }

  Widget _buildTimePeriodSection(String title, IconData icon, List<int> hours) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: hours.map((hour) {
            final label = '${hour.toString().padLeft(2, '0')}:00';
            final isStart = _selectedStartHour == hour;
            final isEnd = _selectedEndHour == hour;
            final isInRange = _selectedStartHour != null &&
                _selectedEndHour != null &&
                hour > _selectedStartHour! &&
                hour < _selectedEndHour!;

            // In end selection mode, disable hours <= start
            final isDisabled = _isSelectingEnd && hour <= _selectedStartHour!;

            final isSelected = isStart || isEnd;
            final isHighlighted = isInRange;

            return GestureDetector(
              onTap: isDisabled ? null : () => _selectHour(hour),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : isHighlighted
                          ? AppColors.primaryContainer
                          : isDisabled
                              ? AppColors.surfaceVariant.withValues(alpha: 0.5)
                              : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : isHighlighted
                            ? AppColors.primaryLight
                            : isDisabled
                                ? AppColors.border.withValues(alpha: 0.3)
                                : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : isDisabled
                            ? AppColors.textHint.withValues(alpha: 0.5)
                            : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _selectHour(int hour) {
    setState(() {
      if (!_isSelectingEnd) {
        // Step 1: Select start hour
        _selectedStartHour = hour;
        _selectedEndHour = null;
        _isSelectingEnd = true;
      } else {
        // Step 2: Select end hour
        if (hour > _selectedStartHour!) {
          _selectedEndHour = hour;
          _isSelectingEnd = false;
        }
      }
    });
  }
}
