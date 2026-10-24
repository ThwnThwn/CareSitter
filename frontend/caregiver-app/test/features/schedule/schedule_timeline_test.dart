import 'package:caregiver_app/features/schedule/presentation/models/timeline_shift_model.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_daily_summary.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_shift_card.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _morningShift = TimelineShift(
  id: 'morning',
  beneficiaryName: 'Bà Trần Thị Mai',
  serviceName: 'Đồng hành & Bầu bạn',
  status: 'confirmed',
  startHour: 8,
  endHour: 10,
  duration: '2 giờ',
  address: 'Quận 3, Hồ Chí Minh',
);

const _afternoonShift = TimelineShift(
  id: 'afternoon',
  beneficiaryName: 'Ông Nguyễn Văn Ba',
  serviceName: 'Hỗ trợ thiết yếu',
  status: 'pending',
  startHour: 14,
  endHour: 18,
  duration: '4 giờ',
  address: 'Quận 1, Hồ Chí Minh',
);

void main() {
  testWidgets('schedule shows the real work total and a long break',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ScheduleDailySummary(
                selectedDate: DateTime(2026, 10, 23),
                shifts: const [_morningShift, _afternoonShift],
              ),
              Expanded(
                child: ScheduleTimeline(
                  timelineScrollController: ScrollController(),
                  selectedDate: DateTime(2026, 10, 23),
                  dayShifts: const <TimelineShift>[
                    _morningShift,
                    _afternoonShift,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('2 ca làm việc · 6 giờ'), findsOneWidget);
    expect(find.text('Khoảng nghỉ: 10:00 – 14:00'), findsOneWidget);
    expect(find.text('Bây giờ'), findsNothing);

    final afternoonCard = find.ancestor(
      of: find.text('Ông Nguyễn Văn Ba'),
      matching: find.byType(ScheduleShiftCard),
    );
    expect(tester.getSize(afternoonCard).height, lessThan(220));
    expect(tester.getSize(find.text('22:00')).height, lessThan(20));
    final morningRail = tester.getRect(
      find.byKey(const ValueKey('schedule-duration-rail-morning')),
    );
    final endHourDot = tester.getCenter(
      find.byKey(const ValueKey('schedule-hour-dot-10')),
    );
    final morningEndDot = tester.getCenter(
      find.byKey(
        const ValueKey('schedule-duration-end-dot-morning'),
      ),
    );
    expect(
      morningRail.bottom,
      moreOrLessEquals(endHourDot.dy, epsilon: 0.1),
    );
    expect(
      morningEndDot.dy,
      moreOrLessEquals(endHourDot.dy, epsilon: 0.1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shift card matches Stitch content and keeps the male avatar',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const shift = TimelineShift(
      id: 'stitch-shift',
      beneficiaryName: 'Ông Nguyễn Văn Ba',
      beneficiaryAge: 78,
      beneficiaryGender: 'MALE',
      serviceName: 'Gói Hỗ trợ thiết yếu',
      status: 'confirmed',
      startHour: 8,
      endHour: 10,
      startMinute: 8 * 60 + 30,
      endMinute: 10 * 60 + 30,
      duration: '2 giờ',
      address: '123 Nguyễn Huệ, P. Bến Nghé, Quận 1, TP. HCM',
      taskTitles: ['Cho ăn uống', 'Uống thuốc đúng giờ'],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 298,
              child: ScheduleShiftCard(shift: shift),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sắp tới'), findsOneWidget);
    expect(find.text('Cho ăn uống'), findsOneWidget);
    expect(find.text('Uống thuốc đúng giờ'), findsOneWidget);
    expect(find.text('2 giờ'), findsOneWidget);
    expect(find.text('Lộ trình'), findsOneWidget);
    expect(
        tester.getSize(find.byType(ScheduleShiftCard)).height, lessThan(220));

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/images/default-avatar-senior-male.png',
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('schedule-action-stitch-shift')))
          .height,
      greaterThanOrEqualTo(44),
    );
    expect(tester.takeException(), isNull);
  });
}
