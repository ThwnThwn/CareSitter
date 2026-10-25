import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import '../controllers/schedule_selectors.dart';
import '../widgets/schedule_header.dart';
import '../widgets/schedule_date_selector.dart';
import '../widgets/schedule_daily_summary.dart';
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
    final targetOffset =
        (now.hour.clamp(0, 23) * ScheduleTimeline.hourExtent - 72)
            .clamp(0.0, double.infinity);
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
          const ScheduleHeader(),
          ScheduleDateSelector(
            isMonthView: _isMonthView,
            selectedDate: _selectedDate,
            weekStart: _weekStart,
            previousPeriod: _previousPeriod,
            nextPeriod: _nextPeriod,
            toggleMonthView: _toggleMonthView,
            onSelectDate: _selectCalendarDate,
          ),
          const SizedBox(height: AppSpacing.xs),
          ScheduleDailySummary(
            selectedDate: _selectedDate,
            shifts: ref.watch(dayShiftsProvider(_selectedDate)),
          ),
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

  void _toggleMonthView() {
    setState(() => _isMonthView = !_isMonthView);
  }
}
