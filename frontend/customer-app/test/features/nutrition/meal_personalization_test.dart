import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/features/nutrition/domain/pantry_ingredients.dart';
import 'package:caresitter_customer/features/nutrition/data/models/meal_feedback_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/meal_feedback_list_model.dart';
import 'package:caresitter_customer/features/nutrition/data/repositories/meal_feedback_repository.dart';
import 'package:caresitter_customer/features/nutrition/data/repositories/nutrition_repository.dart';
import 'package:caresitter_customer/features/nutrition/presentation/controllers/meal_feedback_controller.dart';
import 'package:caresitter_customer/features/nutrition/presentation/controllers/nutrition_actions_controller.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_meal_feedback_panel.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_pantry_field.dart';
import 'support/nutrition_flow_repository.dart';
import 'package:caresitter_customer/features/nutrition/presentation/controllers/nutrition_controller.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_result.dart';

const scope = (beneficiaryId: 'person', planId: 'plan');

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'owner', isAuthenticated: true);
  void change() => state =
      const AsyncData(AuthState(userId: 'second', isAuthenticated: true));
}

class _Feedback extends MealFeedbackRepository {
  _Feedback() : super(_Dio());
  final keys = <String>[];
  final reviews = <({bool approve, int revision})>[];
  final items = <MealFeedbackModel>[];
  int revision = 7;
  bool failOnce = false;
  Completer<void>? pending;
  @override
  Future<MealFeedbackListModel> load(
          String beneficiaryId, String planId, ApiCancellation token) async =>
      MealFeedbackListModel(List.of(items), revision);
  @override
  Future<void> submit(String beneficiaryId, String planId, String recipeId,
      String feedback, String key) async {
    keys.add(key);
    if (failOnce) {
      failOnce = false;
      throw const AppApiException(message: 'Mất kết nối');
    }
    if (pending != null) await pending!.future;
    if (items.isEmpty) {
      items.add(MealFeedbackModel(
          id: 'feedback',
          recipeVersionId: recipeId,
          mealName: 'Cá hấp',
          feedback: feedback,
          status: 'pending',
          submittedByRole: 'CUSTOMER'));
    }
  }

  @override
  Future<void> review(String beneficiaryId, String id, bool approve,
      int expectedRevision) async {
    reviews.add((approve: approve, revision: expectedRevision));
    final before = items.single;
    items[0] = MealFeedbackModel(
        id: before.id,
        recipeVersionId: before.recipeVersionId,
        mealName: before.mealName,
        feedback: before.feedback,
        status: approve ? 'approved' : 'rejected',
        submittedByRole: 'CUSTOMER');
    if (approve) revision++;
  }
}

class _Dio implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

NutritionFlowRepository _nutrition() => NutritionFlowRepository()
  ..saved = NutritionFlowRepository.resource('plan', 'saved',
      decision: 'suggested',
      data: {
        'plannedDate': '2026-01-01',
        'meals': [NutritionFlowRepository.meal('lunch', 'Cá hấp')]
      });

void main() {
  testWidgets(
      'historical plan still offers feedback while new recommendations require recheck',
      (tester) async {
    final repository = _nutrition();
    final controller = NutritionFlowController(repository, 'person', 'owner');
    addTearDown(controller.dispose);
    var opened = 0;
    final stale = NutritionFlowRepository.resource('plan', 'stale', data: {
      ...repository.saved!.payload.cast<String, dynamic>(),
      'isSavedPlan': true,
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: NutritionResult(
                flow: NutritionFlow(resource: stale),
                controller: controller,
                plannedDate: DateTime(2026, 1, 1),
                onReplace: (_) {},
                onConfirm: () {},
                onMealFeedback: () => opened++))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phản hồi món đã ăn'));
    expect(opened, 1);
    expect(find.text('Kiểm tra lại hồ sơ'), findsOneWidget);
    expect(find.text('Lưu thực đơn'), findsNothing);
  });
  test(
      'pantry parses separate ingredients without losing accents and validates limits',
      () {
    expect(PantryIngredients.parse('CÁ, bí đỏ; cá\ntrứng'),
        ['bí đỏ', 'cá', 'trứng']);
    expect(PantryIngredients.parse('cá, cà'), ['cà', 'cá']);
    expect(
        PantryIngredients.error(List.generate(21, (i) => 'món $i').join(',')),
        isNotNull);
    expect(PantryIngredients.error('x'), isNotNull);
  });

  test(
      'recommendation retry retains pantry and operation key while changed ingredients rotate key',
      () async {
    final repository = NutritionFlowRepository()
      ..loseRecommendationResponse = true;
    final actions = NutritionActionsController(repository, 'person');
    final token = ApiCancellation();
    Future<void> send(List<String> ingredients) async {
      await actions.recommend('assessment', 7, token,
          plannedDate: DateTime(2027, 1, 1), availableIngredients: ingredients);
    }

    await expectLater(send(['cá']), throwsA(isA<AppApiException>()));
    await send(['cá']);
    await send(['trứng']);
    expect(repository.writes[0].data['idempotencyKey'],
        repository.writes[1].data['idempotencyKey']);
    expect(repository.writes[2].data['idempotencyKey'],
        isNot(repository.writes[1].data['idempotencyKey']));
    expect(repository.writes[1].data['availableIngredients'], ['cá']);
  });

  test(
      'feedback retries reuse key, double taps are blocked, and old account completion is ignored',
      () async {
    final feedback = _Feedback()..failOnce = true;
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      nutritionRepositoryProvider.overrideWithValue(_nutrition()),
      mealFeedbackRepositoryProvider.overrideWithValue(feedback)
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    container.listen(mealFeedbackProvider(scope), (_, __) {});
    await container.read(mealFeedbackProvider(scope).future);
    final controller = container.read(mealFeedbackProvider(scope).notifier);
    expect(await controller.submit('recipe-lunch', 'liked'), isFalse);
    feedback.pending = Completer<void>();
    final retry = controller.submit('recipe-lunch', 'liked');
    expect(await controller.submit('recipe-lunch', 'liked'), isFalse);
    expect(feedback.keys[0], feedback.keys[1]);
    (container.read(authStateProvider.notifier) as _Auth).change();
    await container.read(mealFeedbackProvider(scope).future);
    feedback.pending!.complete();
    expect(await retry, isFalse);
    expect(
        container.read(mealFeedbackProvider(scope)).requireValue.feedback.items,
        isEmpty);
  });

  testWidgets(
      'family explicitly reviews feedback; narrow screen and large text fit',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final feedback = _Feedback();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_Auth.new),
          nutritionRepositoryProvider.overrideWithValue(_nutrition()),
          mealFeedbackRepositoryProvider.overrideWithValue(feedback)
        ],
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!),
            home: const Scaffold(
                body: NutritionMealFeedbackPanel(scope: scope)))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thích món này'));
    await tester.tap(find.text('Thích món này'));
    await tester.pumpAndSettle();
    expect(feedback.reviews, isEmpty);
    await tester.scrollUntilVisible(find.text('Duyệt cập nhật sở thích'), 150);
    await tester.tap(find.text('Duyệt cập nhật sở thích'));
    await tester.pumpAndSettle();
    expect(feedback.reviews.single, (approve: true, revision: 7));
    expect(find.text('Đã cập nhật sở thích'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pantry draft resets when account changes', (tester) async {
    final container = ProviderContainer(
        overrides: [authStateProvider.overrideWith(_Auth.new)]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
            home: Scaffold(
                body: NutritionPantryField(
                    beneficiaryId: 'person', enabled: true)))));
    await tester.enterText(find.byType(TextFormField), 'cá, bí đỏ');
    await tester.pump();
    (container.read(authStateProvider.notifier) as _Auth).change();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
  });
}
