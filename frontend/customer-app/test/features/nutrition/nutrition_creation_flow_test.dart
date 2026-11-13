import 'dart:async';

import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/core/api/dio_client.dart'
    show AppApiException;
import 'package:caresitter_customer/core/utils/date_formatter.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_resource_model.dart';
import 'package:caresitter_customer/features/nutrition/data/repositories/nutrition_repository.dart';
import 'package:caresitter_customer/features/nutrition/presentation/controllers/nutrition_controller.dart';
import 'package:caresitter_customer/features/nutrition/presentation/screens/nutrition_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/nutrition_flow_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        'nutrition_disclaimer_ack:owner:nutrition-reference-2026-11-10-v1':
            true,
      }));
  testWidgets('profile has one action and saving edits waits for menu creation',
      (tester) async {
    final repository = NutritionFlowRepository()..parsedAssessment = true;
    await _mount(tester, repository, width: 390);
    await tester.tap(find.byTooltip('Cập nhật thông tin dinh dưỡng'));
    await tester.pumpAndSettle();
    expect(find.text('Lưu thông tin'), findsNothing);
    await _press(tester, 'Tạo thực đơn');
    expect(find.text('Tạo thực đơn'), findsOneWidget);
    expect(find.text('Lưu thông tin'), findsNothing);

    final notes = find.text('Lưu ý và hướng dẫn hiện có');
    await tester.scrollUntilVisible(notes, -200,
        scrollable: find.byType(Scrollable).first);
    await _press(tester, 'Lưu ý và hướng dẫn hiện có');
    final note = find.widgetWithText(
        TextField, 'Lưu ý sức khỏe / triệu chứng chưa rõ');
    await tester.ensureVisible(note);
    await tester.enterText(note, 'Ghi chú thử nghiệm');
    await tester.pumpAndSettle();
    expect(find.text('Tạo thực đơn'), findsNothing);
    await _press(tester, 'Lưu thông tin');

    expect(repository.recommendation, isNull);
    expect(repository.savedHistory, isEmpty);
    expect(find.text('Lưu thông tin'), findsNothing);
    expect(find.text('Tạo thực đơn'), findsOneWidget);
    await _press(tester, 'Tạo thực đơn');
    await _selectPlanDays(tester, 3);
    expect(repository.savedHistory, hasLength(3));
  });

  testWidgets('checking parser results waits for explicit confirmation',
      (tester) async {
    final repository = NutritionFlowRepository()..parsedAssessment = true;
    await _mount(tester, repository);
    await _assess(tester);

    expect(find.text('Tạo thực đơn'), findsOneWidget);
    expect(repository.writes.where((write) => write.route.endsWith('/confirm')),
        isEmpty);
    expect(repository.recommendation, isNull);
  });

  testWidgets('weekly creation reserves a menu already saved on a later day',
      (tester) async {
    final repository = NutritionFlowRepository()..uniqueWeeklyMenus = false;
    await _mount(tester, repository, width: 390);
    await _assess(tester);
    final day = DateTime.parse(repository.recommendation!.result.plannedDate!);
    final later = DateTime(day.year, day.month, day.day + 2);
    repository.savedHistory.add(NutritionFlowRepository.resource(
      'already-saved',
      'saved',
      data: {
        ...repository.recommendation!.payload,
        'plannedDate': _apiDate(later),
      },
    ));
    await _createPlan(tester, 7);

    expect(repository.savedHistory.single.id, 'already-saved');
    expect(repository.writes.where((write) => write.route == 'meal-plans'),
        isEmpty);
  });

  for (final status in [403, 409]) {
    testWidgets('weekly creation handles access or revision failure ($status)',
        (tester) async {
      final repository = NutritionFlowRepository();
      await _mount(tester, repository, width: 390);
      await _assess(tester);
      final controller = ProviderScope.containerOf(
        tester.element(find.byType(NutritionScreen)),
      ).read(nutritionControllerProvider('person').notifier);
      final suggestion = repository.recommendation!;
      final date = DateTime.parse(suggestion.result.plannedDate!);
      repository.savedHistory.add(NutritionFlowRepository.resource(
        'already-saved',
        'saved',
        data: suggestion.payload.cast<String, dynamic>(),
      ));
      repository.planReadError = AppApiException(
        message: 'Cannot open saved plan',
        statusCode: status,
        code: status == 409 ? 'nutrition.profile_changed' : null,
      );

      final result = await controller.generateWeek(date);
      await tester.pumpAndSettle();

      expect(result.createdDays, 0);
      if (status == 403) {
        expect(controller.view.health, isNull);
        expect(controller.view.resource, isNull);
      } else {
        expect(controller.view.resource?.status, 'stale');
      }
    });
  }

  testWidgets('opening nutrition stops waiting for a stalled saved plan list',
      (tester) async {
    final repository = NutritionFlowRepository()
      ..pendingWeekList = Completer<void>();
    final controller = NutritionFlowController(repository, 'person', 'owner');
    addTearDown(controller.dispose);
    await tester.pump();

    expect(controller.view.restoringPlan, isTrue);
    await tester.pump(const Duration(seconds: 11));
    await tester.pump();

    expect(controller.view.restoringPlan, isFalse);
    expect(controller.view.health, isNotNull);
    expect(controller.view.error, contains('Không tải kịp thực đơn đã lưu'));
    repository.pendingWeekList!.complete();
    await tester.pump();
    expect(controller.view.resource, isNull);
    expect(controller.view.restoringPlan, isFalse);
  });

  testWidgets('weekly creation stops waiting for a stalled saved plan list',
      (tester) async {
    final repository = NutritionFlowRepository();
    final controller = NutritionFlowController(repository, 'person', 'owner');
    addTearDown(controller.dispose);
    await tester.pump();
    await controller.assess();
    await controller.confirm();
    repository.pendingWeekList = Completer<void>();

    final creating = controller.generateWeek(DateTime(2026, 11, 4));
    await tester.pump(const Duration(seconds: 11));
    expect(controller.view.loading, isFalse);
    final result = await creating;

    expect(result.completed, isFalse);
    expect(result.createdDays, 0);
    expect(controller.view.weekProgress, isNull);
    repository.pendingWeekList!.complete();
  });

  testWidgets(
      'selected calendar date survives automatic recommendation, replacement and save',
      (tester) async {
    final repository = NutritionFlowRepository();
    await _mount(tester, repository, width: 390, textScale: 1.3);
    final selectedDate = await _selectAnotherDay(tester);
    await _assess(tester);

    expect(
        repository.writes.map((write) => write.route),
        containsAllInOrder([
          'nutrition-assessments',
          'nutrition-assessments/assessment-0/confirm',
          'meal-recommendations',
        ]));

    final request = repository.writes.last;
    expect(request.route, 'meal-recommendations');
    expect(request.data['plannedDate'], _apiDate(selectedDate));

    await _press(tester, 'Chọn món thay thế');
    await tester.tap(find.text('Súp bí đỏ'));
    await tester.pumpAndSettle();
    await _press(tester, 'Chọn món này');
    expect(
        repository.writes.last.data['recipeVersionId'], 'replacement-recipe');
    await _press(tester, 'Lưu thực đơn');

    expect(repository.writes.last.data['recommendationId'],
        repository.recommendation!.id);
    expect(repository.saved!.result.plannedDate, _apiDate(selectedDate));
    expect(find.text('Thực đơn dinh dưỡng'), findsOneWidget);
    expect(find.text('Thực đơn đã lưu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'checking valid information generates a recommendation immediately',
      (tester) async {
    final repository = NutritionFlowRepository();
    await _mount(tester, repository);
    await _assess(tester);
    expect(repository.recommendation, isNotNull);
    expect(find.text('Lưu thực đơn'), findsOneWidget);
    expect(find.text('Tạo thực đơn'), findsNothing);
  });

  testWidgets('recommendation retry retains the date and idempotency key',
      (tester) async {
    final repository = NutritionFlowRepository()
      ..loseRecommendationResponse = true;
    await _mount(tester, repository);
    final date = await _selectAnotherDay(tester);
    await _assess(tester);
    await _press(tester, 'Xem gợi ý thực đơn');

    final attempts = repository.writes
        .where((write) => write.route == 'meal-recommendations')
        .toList();
    expect(attempts, hasLength(2));
    expect(attempts.first.data['plannedDate'], _apiDate(date));
    expect(attempts.last.data, attempts.first.data);
    expect(find.text('Lưu thực đơn'), findsOneWidget);
  });

  testWidgets('stale content can be reassessed without editing health data',
      (tester) async {
    final repository = NutritionFlowRepository();
    await _mount(tester, repository);
    await _assess(tester);
    repository.catalogChanged = true;
    await tester.tap(find.byTooltip('Cập nhật thông tin dinh dưỡng'));
    await tester.pumpAndSettle();
    final controller = ProviderScope.containerOf(
      tester.element(find.byType(NutritionScreen)),
    ).read(nutritionControllerProvider('person').notifier);
    await controller.saveHealthAndAssess({}, plannedDate: DateTime.now());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Thông tin đã thay đổi — cần kiểm tra lại'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(
        find.text('Thông tin đã thay đổi — cần kiểm tra lại'), findsOneWidget);
    final previousKey = repository.writes.last.data['idempotencyKey'];
    await _press(tester, 'Kiểm tra lại hồ sơ');

    expect(find.text('Tạo thực đơn'), findsOneWidget);
    expect(repository.writes.last.route, 'nutrition-assessments');
    expect(repository.writes.last.data['idempotencyKey'], isNot(previousKey));
    expect(repository.healthCalls, 2);
  });

  testWidgets('checking a failed assessment starts a new attempt',
      (tester) async {
    final repository = NutritionFlowRepository()..assessmentStatus = 'failed';
    await _mount(tester, repository);
    await _assess(tester);
    final previousKey = repository.writes.last.data['idempotencyKey'];
    repository.assessmentStatus = 'awaiting_confirmation';
    await _press(tester, 'Thử phân tích lại');

    final retry = repository.writes
        .where((write) => write.route == 'nutrition-assessments')
        .last;
    expect(retry.data['idempotencyKey'], isNot(previousKey));
    expect(find.text('Tạo thực đơn'), findsOneWidget);
  });

  testWidgets('opening a saved plan ignores a late assessment polling response',
      (tester) async {
    final repository = NutritionFlowRepository()
      ..assessmentStatus = 'queued'
      ..pendingAssessmentRead = Completer<NutritionResourceModel>();
    final controller = NutritionFlowController(repository, 'person', 'owner');
    addTearDown(controller.dispose);
    await tester.pump();
    await controller.assess();
    // Let the real poller start its first request, then navigate to history.
    await tester.pump(const Duration(seconds: 2));
    repository.saved = NutritionFlowRepository.resource('saved-plan', 'saved',
        decision: 'suggested', data: {'plannedDate': '2026-10-23'});
    await controller.openPlan('saved-plan');
    repository.pendingAssessmentRead!.complete(
      NutritionFlowRepository.resource('assessment', 'awaiting_confirmation'),
    );
    await tester.pump();

    expect(controller.view.resource!.id, 'saved-plan');
    expect(controller.view.resource!.status, 'saved');
  });

  testWidgets('queued assessment continues to a meal after polling',
      (tester) async {
    final repository = NutritionFlowRepository()..assessmentStatus = 'queued';
    final controller = NutritionFlowController(repository, 'person', 'owner');
    addTearDown(controller.dispose);
    await tester.pump();

    await controller
        .saveHealthAndAssess(const {}, plannedDate: DateTime(2026, 11, 4));
    expect(controller.view.resource?.status, 'queued');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(controller.view.resource?.status, 'suggested');
    expect(repository.writes.last.route, 'meal-recommendations');
    expect(repository.writes.last.data['plannedDate'], '2026-11-04');
  });

  testWidgets('a lost retry response reuses the new assessment attempt key',
      (tester) async {
    final repository = NutritionFlowRepository()..assessmentStatus = 'failed';
    await _mount(tester, repository);
    await _assess(tester);
    repository
      ..assessmentStatus = 'awaiting_confirmation'
      ..loseAssessmentResponse = true;
    await _press(tester, 'Thử phân tích lại');
    await _press(tester, 'Thử phân tích lại');

    expect(repository.writes.take(3).map((write) => write.route),
        everyElement('nutrition-assessments'));
    expect(repository.writes[1].data['idempotencyKey'],
        isNot(repository.writes[0].data['idempotencyKey']));
    expect(repository.writes[2].data, repository.writes[1].data);
    expect(find.text('Tạo thực đơn'), findsOneWidget);
  });

  testWidgets('failed history loading resumes the pending assessment',
      (tester) async {
    final repository = NutritionFlowRepository()
      ..assessmentStatus = 'queued'
      ..planReadError =
          const AppApiException(message: 'Mất kết nối', statusCode: 503);
    final controller = NutritionFlowController(repository, 'person', 'owner');
    addTearDown(controller.dispose);
    await tester.pump();
    await controller.assess();
    await controller.openPlan('unavailable');
    expect(controller.view.resource!.status, 'queued');

    await tester.pump(const Duration(seconds: 2));

    expect(controller.view.resource!.status, 'awaiting_confirmation');
  });

  testWidgets(
      'a non-retryable failure cannot be resubmitted from the main button',
      (tester) async {
    final repository = NutritionFlowRepository()
      ..assessmentStatus = 'failed'
      ..assessmentRetryable = false;
    await _mount(tester, repository);
    await _assess(tester);

    expect(find.text('Tạo thực đơn'), findsNothing);
    expect(find.text('Thử phân tích lại'), findsNothing);
    expect(repository.writes, hasLength(1));
  });

  testWidgets('creation actions stay usable at width 320 with large text',
      (tester) async {
    final repository = NutritionFlowRepository();
    await _mount(tester, repository, width: 320, textScale: 2);
    await _selectAnotherDay(tester);
    await _press(tester, 'Tạo thực đơn cho ngày này');
    await _press(tester, 'Tạo thực đơn');
    await _press(tester, 'Lưu thực đơn');

    expect(repository.saved, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plan setup sheet fits width 320 with large text',
      (tester) async {
    final repository = NutritionFlowRepository();
    await _mount(tester, repository, width: 320, textScale: 2);
    await _assess(tester);
    await _press(tester, 'Tạo thực đơn mới');

    expect(find.text('Khoảng thời gian'), findsOneWidget);
    expect(find.byKey(const ValueKey('nutrition-plan-days-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('nutrition-plan-days-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('nutrition-plan-days-7')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a confirmed health assessment is reused when creating another day',
      (tester) async {
    final repository = NutritionFlowRepository();
    await _mount(tester, repository, width: 390);
    await _assess(tester);
    await _press(tester, 'Lưu thực đơn');
    final originalAssessmentId = repository.saved!.payload['assessmentId'];

    final selectedDate = await _selectAnotherDay(tester);
    await _press(tester, 'Tạo thực đơn cho ngày này');

    expect(find.text('Tạo thực đơn'), findsNothing);
    expect(repository.writes.last.route, 'meal-recommendations');
    expect(repository.writes.last.data['assessmentId'], originalAssessmentId);
    expect(repository.writes.last.data['plannedDate'], _apiDate(selectedDate));
    expect(find.text('Lưu thực đơn'), findsOneWidget);
  });

  testWidgets('creates and saves seven different daily menus', (tester) async {
    final repository = NutritionFlowRepository();
    await _mount(tester, repository, width: 390);
    await _assess(tester);
    await _createPlan(tester, 7);

    expect(repository.savedHistory, hasLength(7));
    expect(
        repository.savedHistory.map((plan) => plan.result.plannedDate).toSet(),
        hasLength(7));
    expect(
        repository.savedHistory
            .map((plan) => plan.result.meals.map((meal) => meal.name).join('|'))
            .toSet(),
        hasLength(7));
    expect(find.text('Đã lưu thực đơn cho đủ 7 ngày'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final days in [3, 5]) {
    testWidgets(
        'creates and saves a $days day plan selected from the setup sheet',
        (tester) async {
      final repository = NutritionFlowRepository();
      await _mount(tester, repository, width: 390);
      await _assess(tester);
      await _createPlan(tester, days);

      expect(repository.savedHistory, hasLength(days));
      expect(find.text('Đã lưu thực đơn cho đủ $days ngày'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'weekly creation keeps an existing day and fills the remaining six',
      (tester) async {
    final repository = NutritionFlowRepository();
    await _mount(tester, repository, width: 390);
    await _assess(tester);
    await _press(tester, 'Lưu thực đơn');
    final firstPlan = repository.saved!.id;
    await _createPlan(tester, 7);

    expect(repository.savedHistory, hasLength(7));
    expect(repository.savedHistory.first.id, firstPlan);
    expect(repository.writes.where((write) => write.route == 'meal-plans'),
        hasLength(7));
  });

  testWidgets('weekly creation stops before saving a duplicate menu',
      (tester) async {
    final repository = NutritionFlowRepository()..uniqueWeeklyMenus = false;
    await _mount(tester, repository, width: 390);
    await _assess(tester);
    await _createPlan(tester, 7);

    expect(repository.savedHistory, hasLength(1));
    expect(find.textContaining('Đã có 1/7 ngày.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirming the summary automatically saves the selected week',
      (tester) async {
    final repository = NutritionFlowRepository();
    await _mount(tester, repository, width: 390);
    final controller = ProviderScope.containerOf(
      tester.element(find.byType(NutritionScreen)),
    ).read(nutritionControllerProvider('person').notifier);
    await controller.assess();
    await tester.pumpAndSettle();
    repository.pendingWeekList = Completer<void>();
    final confirm = find.text('Tạo thực đơn');
    await tester.scrollUntilVisible(confirm, 200,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(confirm), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await _selectPlanDays(tester, 7, settle: false);
    await tester.pump();
    expect(find.text('Lưu thông tin thành công'), findsOneWidget);
    final progress = find.byKey(const ValueKey('nutrition-week-progress'));
    expect(progress, findsOneWidget);
    expect(tester.getSize(progress).width, closeTo(350, 1));
    expect(find.text('Đã lưu 0/7 ngày'), findsOneWidget);
    expect(find.text('Tạo thực đơn'), findsNothing);
    expect(find.text('Xem gợi ý thực đơn'), findsNothing);
    repository.pendingWeekList!.complete();
    await tester.pumpAndSettle();

    expect(repository.savedHistory, hasLength(7));
    expect(find.text('Tạo thực đơn'), findsNothing);
    expect(find.text('Thực đơn đã lưu'), findsOneWidget);
  });

  testWidgets('failed confirmation does not claim success or create meals',
      (tester) async {
    final repository = NutritionFlowRepository()
      ..confirmationError = const AppApiException(
          message: 'Không xác nhận được', statusCode: 503);
    await _mount(tester, repository, width: 390);
    final controller = ProviderScope.containerOf(
      tester.element(find.byType(NutritionScreen)),
    ).read(nutritionControllerProvider('person').notifier);
    await controller.assess();
    await tester.pumpAndSettle();
    await _press(tester, 'Tạo thực đơn');
    await _selectPlanDays(tester, 7);

    expect(repository.savedHistory, isEmpty);
    expect(find.text('Lưu thông tin thành công'), findsNothing);
    expect(
        repository.writes
            .where((write) => write.route == 'meal-recommendations'),
        isEmpty);
  });
}

Future<void> _mount(WidgetTester tester, NutritionFlowRepository repository,
    {double width = 800, double textScale = 1}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(_Auth.new),
      nutritionRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const NutritionScreen(beneficiaryId: 'person'),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _assess(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Cập nhật thông tin dinh dưỡng'));
  await tester.pumpAndSettle();
  await _press(tester, 'Tạo thực đơn');
}

Future<void> _press(WidgetTester tester, String label) async {
  if (label == 'Chọn món thay thế') {
    for (var i = 0; i < 20 && find.text(label).evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
      await tester.pumpAndSettle();
    }
  }
  final target =
      label == 'Chọn món thay thế' ? find.text(label).first : find.text(label);
  await tester.scrollUntilVisible(target, 200,
      scrollable: find.byType(Scrollable).first);
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _createPlan(WidgetTester tester, int days) async {
  // The create control is above the saved dishes; saving can leave the taller
  // per-dish cards scrolled to the bottom of the menu.
  final position =
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;
  position.jumpTo(position.minScrollExtent);
  await tester.pumpAndSettle();
  await _press(tester, 'Tạo thực đơn mới');
  await _selectPlanDays(tester, days);
}

Future<void> _selectPlanDays(WidgetTester tester, int days,
    {bool settle = true}) async {
  await tester.tap(find.byKey(ValueKey('nutrition-plan-days-$days')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('nutrition-create-plan-submit')));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<DateTime> _selectAnotherDay(WidgetTester tester) async {
  final today = DateUtils.dateOnly(DateTime.now());
  final date =
      today.add(Duration(days: today.weekday == DateTime.sunday ? -1 : 1));
  final scrollable = find.byType(Scrollable).first;
  final towardTop =
      tester.state<ScrollableState>(scrollable).position.pixels > 0;
  for (var i = 0; i < 10 && find.text('${date.day}').evaluate().isEmpty; i++) {
    await tester.drag(scrollable, Offset(0, towardTop ? 240 : -160));
    await tester.pumpAndSettle();
  }
  final day = find.text('${date.day}').last;
  await Scrollable.ensureVisible(tester.element(day), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(day);
  await tester.pumpAndSettle();
  final notice =
      find.text('Chưa có thực đơn cho ngày ${formatDate(date, padded: true)}');
  await tester.scrollUntilVisible(notice, 200,
      scrollable: find.byType(Scrollable).first);
  expect(notice, findsOneWidget);
  return date;
}

String _apiDate(DateTime date) => date.toIso8601String().split('T').first;

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'owner', isAuthenticated: true);
}
