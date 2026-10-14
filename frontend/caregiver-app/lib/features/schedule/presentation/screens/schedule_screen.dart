import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import '../controllers/schedule_selectors.dart';
import '../widgets/schedule_header.dart';
import '../widgets/schedule_date_selector.dart';
import '../widgets/schedule_timeline.dart';

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

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: Column(children: [
          ScheduleHeader(
            pickDate: _pickDate,
            selectedDate: _selectedDate,
            isMonthView: _isMonthView,
            previousPeriod: _previousPeriod,
            nextPeriod: _nextPeriod,
          ),
          ScheduleDateSelector(
            isMonthView: _isMonthView,
            selectedDate: _selectedDate,
            weekStart: _weekStart,
            onSelectDate: _selectCalendarDate,
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
              child: ScheduleTimeline(
            timelineScrollController: _timelineScrollController,
            dayShifts: ref.watch(dayShiftsProvider(_selectedDate)),
            selectedDate: _selectedDate,
          )),
        ]),
      );

  void _selectCalendarDate(DateTime date) {
    _selectDate(date);
    if (_isMonthView) {
      setState(() {
        _isMonthView = false;
        _weekStart = _getWeekStart(date);
      });
    }
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
}
