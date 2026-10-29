import 'package:caresitter_customer/features/nutrition/data/models/nutrition_resource_model.dart';
import 'package:caresitter_customer/features/nutrition/presentation/models/nutrition_flow_model.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_menu_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('menu overview stays readable at compact width', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final flow = NutritionFlow(
      resource: NutritionResourceModel.fromJson({
        'status': 'saved',
        'data': {
          'plannedDate': '2026-10-22',
          'decision': {'state': 'suggested'},
          'meals': [
            {
              'mealType': 'breakfast',
              'name': 'Cháo gạo tẻ đậu phụ và cà chua',
              'servings': 1,
              'nutrients': {'energy_kcal': 320},
            },
            {
              'mealType': 'lunch',
              'name': 'Cơm đậu xanh, cải thìa và hành tây',
              'servings': 1,
              'nutrients': {'energy_kcal': 540},
            },
          ],
        },
      }),
    );

    DateTime? selectedDate;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(
          home: Scaffold(
            body: NutritionMenuView(
              beneficiaryName: 'Trần Thị Loan',
              flow: flow,
              onDateSelected: (date) => selectedDate = date,
              result: const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thực đơn ngày 22/10'), findsOneWidget);
    expect(find.textContaining('860 kcal'), findsOneWidget);
    expect(find.text('Lịch thực đơn'), findsOneWidget);
    expect(find.text('22'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('23'));
    expect(selectedDate, DateTime(2026, 10, 23));
  });

  testWidgets('missing date plan shows an inline notice instead of old meals',
      (tester) async {
    final flow = NutritionFlow(
      resource: NutritionResourceModel.fromJson({
        'status': 'saved',
        'data': {
          'plannedDate': '2026-10-22',
          'decision': {'state': 'suggested'},
          'meals': [
            {
              'mealType': 'breakfast',
              'name': 'Món của ngày cũ',
              'servings': 1,
              'nutrients': {'energy_kcal': 320},
            },
          ],
        },
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NutritionMenuView(
          beneficiaryName: 'Trần Thị Loan',
          flow: flow,
          selectedDate: DateTime(2026, 10, 23),
          hasPlanForSelectedDate: false,
          result: const Text('Món của ngày cũ'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final notice = find.text('Chưa có thực đơn cho ngày 23/10/2026');
    await tester.scrollUntilVisible(notice, 120);
    expect(find.text('Chưa có thực đơn cho ngày 23/10/2026'), findsOneWidget);
    expect(find.text('Món của ngày cũ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing-plan notice fits a narrow screen with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
      child: MaterialApp(
        home: Scaffold(
          body: NutritionMenuView(
            beneficiaryName: 'Trần Thị Loan',
            flow: const NutritionFlow(),
            selectedDate: DateTime(2026, 10, 23),
            hasPlanForSelectedDate: false,
            result: const SizedBox.shrink(),
            onCreatePlan: () {},
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    final notice = find.text('Chưa có thực đơn cho ngày 23/10/2026');
    await tester.scrollUntilVisible(notice, 120);
    expect(notice, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading a new date hides the previously opened menu',
      (tester) async {
    final flow = NutritionFlow(
      resource: NutritionResourceModel.fromJson({
        'status': 'saved',
        'data': {
          'plannedDate': '2026-10-22',
          'decision': {'state': 'suggested'},
          'meals': [
            {
              'mealType': 'breakfast',
              'name': 'Món của ngày cũ',
              'servings': 1,
            },
          ],
        },
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NutritionMenuView(
          beneficiaryName: 'Trần Thị Loan',
          flow: flow,
          selectedDate: DateTime(2026, 10, 23),
          hasPlanForSelectedDate: true,
          isLoadingSelectedDate: true,
          result: const Text('Món của ngày cũ'),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Đang tải'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Món của ngày cũ'), findsNothing);
    expect(find.text('Chưa có thực đơn cho ngày 23/10/2026'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
