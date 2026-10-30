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

import 'support/nutrition_flow_repository.dart';

void main() {
  testWidgets(
      'selected calendar date survives confirmation, replacement and save',
      (tester) async {
    final repository = NutritionFlowRepository();
    await _mount(tester, repository, width: 390, textScale: 1.3);
    final selectedDate = await _selectAnotherDay(tester);
    await _assess(tester);
    await _press(tester, 'Thông tin đúng, tiếp tục');
    await _press(tester, 'Xem gợi ý thực đơn');

    final request = repository.writes.last;
    expect(request.route, 'meal-recommendations');
    expect(request.data['plannedDate'], _apiDate(selectedDate));

    await _press(tester, 'Chọn món thay thế');
    await tester.tap(find.text('Súp bí đỏ'));
    await tester.pumpAndSettle();
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
      'returning to the calendar keeps the pending confirmation visible',
      (tester) async {
    await _mount(tester, NutritionFlowRepository());
    await _assess(tester);
    await tester.tap(find.byTooltip('Quay lại thực đơn'));
    await tester.pumpAndSettle();

    expect(find.text('Kiểm tra bản tóm tắt'), findsOneWidget);
    expect(find.text('Thông tin đúng, tiếp tục'), findsOneWidget);
    expect(find.textContaining('Chưa có thực đơn cho ngày'), findsNothing);
  });

  testWidgets('recommendation retry retains the date and idempotency key',
      (tester) async {
    final repository = NutritionFlowRepository()
      ..loseRecommendationResponse = true;
    await _mount(tester, repository);
    final date = await _selectAnotherDay(tester);
    await _assess(tester);
    await _press(tester, 'Thông tin đúng, tiếp tục');
    await _press(tester, 'Xem gợi ý thực đơn');
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
    await _press(tester, 'Thông tin đúng, tiếp tục');
    await _press(tester, 'Xem gợi ý thực đơn');
    repository.catalogChanged = true;
    await _press(tester, 'Kiểm tra thông tin');
    expect(
        find.text('Thông tin đã thay đổi — cần kiểm tra lại'), findsOneWidget);
    final previousKey = repository.writes.last.data['idempotencyKey'];
    await _press(tester, 'Kiểm tra lại hồ sơ');

    expect(find.text('Thông tin đúng, tiếp tục'), findsOneWidget);
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
    await _press(tester, 'Kiểm tra thông tin');

    expect(repository.writes.last.data['idempotencyKey'], isNot(previousKey));
    expect(find.text('Thông tin đúng, tiếp tục'), findsOneWidget);
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

  testWidgets('a lost retry response reuses the new assessment attempt key',
      (tester) async {
    final repository = NutritionFlowRepository()..assessmentStatus = 'failed';
    await _mount(tester, repository);
    await _assess(tester);
    repository
      ..assessmentStatus = 'awaiting_confirmation'
      ..loseAssessmentResponse = true;
    await _press(tester, 'Kiểm tra thông tin');
    await _press(tester, 'Kiểm tra thông tin');

    expect(repository.writes, hasLength(3));
    expect(repository.writes[1].data['idempotencyKey'],
        isNot(repository.writes[0].data['idempotencyKey']));
    expect(repository.writes[2].data, repository.writes[1].data);
    expect(find.text('Thông tin đúng, tiếp tục'), findsOneWidget);
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

    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Kiểm tra thông tin'))
            .onPressed,
        isNull);
    expect(find.text('Thử phân tích lại'), findsNothing);
    expect(repository.writes, hasLength(1));
  });

  testWidgets('creation actions stay usable at width 320 with large text',
      (tester) async {
    final repository = NutritionFlowRepository();
    await _mount(tester, repository, width: 320, textScale: 2);
    await _selectAnotherDay(tester);
    await _press(tester, 'Tạo thực đơn cho ngày này');
    await _press(tester, 'Kiểm tra thông tin');
    await _press(tester, 'Thông tin đúng, tiếp tục');
    await _press(tester, 'Xem gợi ý thực đơn');
    await _press(tester, 'Lưu thực đơn');

    expect(repository.saved, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a confirmed health assessment is reused when creating another day',
      (tester) async {
    final repository = NutritionFlowRepository();
    await _mount(tester, repository, width: 390);
    await _assess(tester);
    await _press(tester, 'Thông tin đúng, tiếp tục');
    await _press(tester, 'Xem gợi ý thực đơn');
    await _press(tester, 'Lưu thực đơn');
    final originalAssessmentId = repository.saved!.payload['assessmentId'];

    final selectedDate = await _selectAnotherDay(tester);
    await _press(tester, 'Tạo thực đơn cho ngày này');

    expect(find.text('Kiểm tra thông tin'), findsNothing);
    expect(repository.writes.last.route, 'meal-recommendations');
    expect(repository.writes.last.data['assessmentId'], originalAssessmentId);
    expect(repository.writes.last.data['plannedDate'], _apiDate(selectedDate));
    expect(find.text('Lưu thực đơn'), findsOneWidget);
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
  await _press(tester, 'Kiểm tra thông tin');
}

Future<void> _press(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.scrollUntilVisible(target, 200,
      scrollable: find.byType(Scrollable).first);
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<DateTime> _selectAnotherDay(WidgetTester tester) async {
  final today = DateUtils.dateOnly(DateTime.now());
  final date =
      today.add(Duration(days: today.weekday == DateTime.sunday ? -1 : 1));
  final day = find.text('${date.day}').last;
  await tester.scrollUntilVisible(day, 200,
      scrollable: find.byType(Scrollable).first);
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
