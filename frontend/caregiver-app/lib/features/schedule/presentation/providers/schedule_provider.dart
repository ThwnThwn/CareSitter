import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_constants.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/auth/auth_notifier.dart';

/// Represents a single availability time slot.
class AvailabilitySlot {
  final String id;
  final DateTime date;
  final int startHour; // 0-23
  final int endHour; // 1-24
  final bool isBooked; // true if a shift occupies this slot

  const AvailabilitySlot({
    required this.id,
    required this.date,
    required this.startHour,
    required this.endHour,
    this.isBooked = false,
  });

  AvailabilitySlot copyWith({
    DateTime? date,
    int? startHour,
    int? endHour,
    bool? isBooked,
  }) {
    return AvailabilitySlot(
      id: id,
      date: date ?? this.date,
      startHour: startHour ?? this.startHour,
      endHour: endHour ?? this.endHour,
      isBooked: isBooked ?? this.isBooked,
    );
  }

  String get timeLabel {
    final startStr = '${startHour.toString().padLeft(2, '0')}:00';
    final endStr = '${endHour.toString().padLeft(2, '0')}:00';
    return '$startStr - $endStr';
  }

  String get periodLabel {
    if (startHour < 12) return 'Sáng';
    if (startHour < 18) return 'Chiều';
    return 'Tối';
  }
}

/// Represents a booked shift to display on the timeline.
class TimelineShift {
  final String id;
  final String beneficiaryName;
  final String serviceName;
  final String status;
  final int startHour;
  final int endHour;
  final String duration;
  final String address;

  const TimelineShift({
    required this.id,
    required this.beneficiaryName,
    required this.serviceName,
    required this.status,
    required this.startHour,
    required this.endHour,
    required this.duration,
    required this.address,
  });
}

class ScheduleNotifier extends StateNotifier<List<AvailabilitySlot>> {
  final Ref _ref;

  ScheduleNotifier(this._ref) : super([]) {
    _ref.listen(authStateProvider, (previous, next) {
      if (next.value?.isAuthenticated ?? false) {
        refresh();
      } else {
        state = [];
      }
    });
    refresh();
  }

  DioClient get _dio => _ref.read(dioClientProvider);

  Future<void> refresh() async {
    final isAuth = _ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuth) {
      state = [];
      return;
    }

    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    final to = from.add(const Duration(days: 45));

    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.myAvailability,
        query: {
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
        },
      );
      final rawSlots = response.data ?? const [];
      state = rawSlots
          .whereType<Map<String, dynamic>>()
          .map(_mapSlot)
          .whereType<AvailabilitySlot>()
          .toList()
        ..sort((a, b) {
          final dateCompare = a.date.compareTo(b.date);
          return dateCompare != 0
              ? dateCompare
              : a.startHour.compareTo(b.startHour);
        });
    } catch (e) {
      // ignore: avoid_print
      print('[ScheduleNotifier] Lỗi tải lịch rảnh: $e');
    }
  }

  List<AvailabilitySlot> getSlotsForDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    return state.where((s) {
      final slotDate = DateTime(s.date.year, s.date.month, s.date.day);
      return slotDate == target;
    }).toList()
      ..sort((a, b) => a.startHour.compareTo(b.startHour));
  }

  Future<void> addSlot(DateTime date, int startHour, int endHour) async {
    final startAt = DateTime(date.year, date.month, date.day, startHour);
    final endAt = DateTime(date.year, date.month, date.day, endHour);

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.myAvailability,
        data: {
          'startAt': startAt.toUtc().toIso8601String(),
          'endAt': endAt.toUtc().toIso8601String(),
          'status': 'AVAILABLE',
        },
      );
      final slot = _mapSlot(response.data ?? {});
      if (slot != null) {
        state = [...state.where((s) => s.id != slot.id), slot]..sort((a, b) {
            final dateCompare = a.date.compareTo(b.date);
            return dateCompare != 0
                ? dateCompare
                : a.startHour.compareTo(b.startHour);
          });
      } else {
        await refresh();
      }
      return;
    } catch (e) {
      // ignore: avoid_print
      print('[ScheduleNotifier] Lỗi thêm lịch rảnh: $e');
      return;
    }
  }

  Future<void> removeSlot(String id) async {
    try {
      await _dio.delete<void>('${ApiPaths.myAvailability}/$id');
    } catch (e) {
      // ignore: avoid_print
      print('[ScheduleNotifier] Lỗi xóa lịch rảnh: $e');
      return;
    }
    state = state.where((s) => s.id != id).toList();
  }

  bool hasSlotAt(DateTime date, int hour) {
    final target = DateTime(date.year, date.month, date.day);
    return state.any((s) {
      final slotDate = DateTime(s.date.year, s.date.month, s.date.day);
      return slotDate == target && hour >= s.startHour && hour < s.endHour;
    });
  }

  AvailabilitySlot? _mapSlot(Map<String, dynamic> json) {
    final id = _string(json['id'] ?? json['Id']);
    final start = _date(json['startAt'] ?? json['StartAt']);
    final end = _date(json['endAt'] ?? json['EndAt']);
    if (id == null || start == null || end == null) return null;

    return AvailabilitySlot(
      id: id,
      date: DateTime(start.year, start.month, start.day),
      startHour: start.hour,
      endHour: end.hour == 0 && end.day != start.day ? 24 : end.hour,
      isBooked:
          (_string(json['status'] ?? json['Status']) ?? '').toUpperCase() ==
              'BLOCKED',
    );
  }

  static DateTime? _date(Object? value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }

  static String? _string(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

final scheduleProvider =
    StateNotifierProvider<ScheduleNotifier, List<AvailabilitySlot>>((ref) {
  return ScheduleNotifier(ref);
});
