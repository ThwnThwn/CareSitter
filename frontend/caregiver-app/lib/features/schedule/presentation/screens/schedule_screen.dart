import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_day_cell.dart';
import 'package:caregiver_app/features/schedule/presentation/models/schedule_date_labels.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_content.dart';
import 'package:caregiver_app/features/schedule/presentation/controllers/schedule_selectors.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_header.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_date_selector.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_month_grid.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_timeline.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_shift_card.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_availability_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/schedule/data/models/schedule_slot_model.dart';
import 'package:caregiver_app/features/schedule/presentation/controllers/schedule_controller.dart';

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
    if (!mounted) return;
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

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final daySlots = ref.watch(daySlotsProvider(_selectedDate));
    final dayShifts = ref.watch(dayShiftsProvider(_selectedDate));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ScheduleContent(
          buildHeader: _buildHeader,
          buildDateSelector: _buildDateSelector,
          buildTimeline: _buildTimeline,
          daySlots: daySlots,
          dayShifts: dayShifts),
    );
  }

  Widget _buildHeader() => ScheduleHeader(
      pickDate: _pickDate,
      getMonthName: scheduleMonthName,
      selectedDate: _selectedDate,
      isMonthView: _isMonthView,
      getFullDayOfWeekName: scheduleFullDayName,
      buildNavButton: _buildNavButton,
      previousPeriod: _previousPeriod,
      nextPeriod: _nextPeriod);

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
    if (picked != null && mounted) _selectDate(picked);
  }

  // ────────────────────────────────────────────────────────────────
  // DATE SELECTOR — week strip or full month grid
  // ────────────────────────────────────────────────────────────────
  Widget _buildDateSelector() => ScheduleDateSelector(
      getMonthName: scheduleMonthName,
      isMonthView: _isMonthView,
      selectedDate: _selectedDate,
      weekStart: _weekStart,
      buildMonthGrid: _buildMonthGrid,
      buildWeekStrip: _buildWeekStrip);

  // ── Week strip (original 7-day horizontal list) ──
  Widget _buildWeekStrip() {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.section),
        itemCount: 7,
        itemBuilder: (context, index) {
          final date = _weekStart.add(Duration(days: index));
          return _buildDayCell(date, chipWidth: 48);
        },
      ),
    );
  }

  // ── Full month grid ──
  Widget _buildMonthGrid() => ScheduleMonthGrid(
      selectedDate: _selectedDate, buildDayCell: _buildDayCell);

  // ── Shared day cell widget ──
  Widget _buildDayCell(DateTime date,
      {double chipWidth = 48, bool compact = false}) {
    final isSelected = date.day == _selectedDate.day &&
        date.month == _selectedDate.month &&
        date.year == _selectedDate.year;
    final isCurrentDay = _isToday(date);
    final dayName = scheduleDayName(date.weekday);
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
      child: ScheduleDayCell(
          chipWidth: chipWidth,
          compact: compact,
          isSelected: isSelected,
          isCurrentDay: isCurrentDay,
          date: date,
          dayName: dayName,
          hasSlots: hasSlots),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // TIMELINE — vertical timeline with hour labels + shift cards
  // ────────────────────────────────────────────────────────────────
  Widget _buildTimeline(
          List<AvailabilitySlot> daySlots, List<TimelineShift> dayShifts) =>
      ScheduleTimeline(
          timelineScrollController: _timelineScrollController,
          daySlots: daySlots,
          dayShifts: dayShifts,
          isToday: _isToday,
          selectedDate: _selectedDate,
          buildShiftCard: _buildShiftCard,
          isSlotStart: _isSlotStart,
          buildAvailabilityIndicator: _buildAvailabilityIndicator);

  bool _isSlotStart(List<AvailabilitySlot> slots, int hour) {
    return slots.any((s) => s.startHour == hour);
  }

  // ── Shift Card (similar to the reference image appointment card) ──
  Widget _buildShiftCard(TimelineShift shift) =>
      ScheduleShiftCard(shift: shift);

  // ── Availability Indicator (teal outlined chip) ──
  Widget _buildAvailabilityIndicator(
          AvailabilitySlot slot, BuildContext context) =>
      ScheduleAvailabilityChip(
          slot: slot, confirmRemoveSlot: _confirmRemoveSlot);

  void _confirmRemoveSlot(AvailabilitySlot slot) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
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
