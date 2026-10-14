import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/features/schedule/presentation/controllers/schedule_selectors.dart';
import 'package:caregiver_app/features/schedule/presentation/models/timeline_shift_model.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_day_cell.dart';

void main() {
  testWidgets('calendar reacts to booked shifts and selects the displayed date',
      (tester) async {
    final date = DateTime(2026, 10, 13);
    final shifts = StateProvider<List<TimelineShift>>((_) => []);
    final container = ProviderContainer(overrides: [
      dayShiftsProvider(date).overrideWith((ref) => ref.watch(shifts)),
    ]);
    addTearDown(container.dispose);
    DateTime? selected;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          home: Scaffold(
              body: SizedBox(
        height: 72,
        child: ScheduleDayCell(
            date: date,
            selectedDate: date.subtract(const Duration(days: 1)),
            onSelectDate: (value) => selected = value),
      ))),
    ));
    expect(find.bySemanticsLabel('13/10/2026, có ca chăm sóc'), findsNothing);
    container.read(shifts.notifier).state = [
      const TimelineShift(
        id: 'booking',
        beneficiaryName: 'Người thân',
        serviceName: 'Chăm sóc',
        status: 'confirmed',
        startHour: 8,
        endHour: 12,
        duration: '4 giờ',
        address: 'Địa chỉ',
      )
    ];
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('13/10/2026, có ca chăm sóc')),
        findsOneWidget);
    await tester.tap(find.text('13'));
    expect(selected, date);
  });
}
