import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/auth/auth_state.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/meals/data/models/booking_meal_model.dart';
import 'package:caregiver_app/features/meals/data/models/booking_meal_plan_model.dart';
import 'package:caregiver_app/features/meals/data/models/booking_meal_record_model.dart';
import 'package:caregiver_app/features/meals/data/models/booking_meals_model.dart';
import 'package:caregiver_app/features/meals/data/repositories/booking_meals_repository.dart';
import 'package:caregiver_app/features/meals/presentation/screens/booking_meals_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> mount(WidgetTester tester, _Meals meals) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWith(_Auth.new),
        bookingMealsRepositoryProvider.overrideWithValue(meals),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: const BookingMealsScreen(bookingId: 'booking'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'caregiver reads recipe, records, then submits a reason and revision',
      (tester) async {
    final meals = _Meals();
    await mount(tester, meals);
    await tester.tap(find.text('Cháo bí đỏ'));
    await tester.pumpAndSettle();
    expect(find.text('Bí đỏ · 100 g'), findsOneWidget);
    await tester.tap(find.text('Ghi nhận bữa ăn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kết quả bữa ăn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ăn một phần').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ăn nửa phần');
    await tester.ensureVisible(find.text('Lưu ghi nhận'));
    await tester.tap(find.text('Lưu ghi nhận'));
    await tester.pumpAndSettle();
    expect(meals.recorded,
        ('plan', 'recipe', 'lunch', 'partly_eaten', 'Ăn nửa phần'));
    expect(find.text('Ghi nhận bữa ăn'), findsNothing);

    await tester.ensureVisible(find.text('Đính chính'));
    await tester.tap(find.text('Đính chính'));
    await tester.pumpAndSettle();
    final save = find.text('Lưu đính chính');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Nhập lý do đính chính.'), findsOneWidget);
    expect(meals.corrected, isNull);
    await tester.enterText(
        find.byType(TextField).last, 'Cập nhật theo phần còn lại');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(meals.corrected, ('record', 'Cập nhật theo phần còn lại', 1));
    expect(find.text('Bữa trưa · Ăn một phần'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale plans hide recipe and recording on the caregiver screen',
      (tester) async {
    final meals = _Meals(stale: true);
    await mount(tester, meals);
    expect(find.text('Chờ gia đình chia sẻ lại'), findsOneWidget);
    expect(find.text('Cháo bí đỏ'), findsNothing);
    expect(find.text('Ghi nhận bữa ăn'), findsNothing);
  });
}

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'caregiver', isAuthenticated: true);
}

class _NoHttp implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected HTTP call: ${invocation.memberName}');
}

class _Meals extends BookingMealsRepository {
  _Meals({this.stale = false}) : super(_NoHttp());
  final bool stale;
  (String, String, String, String, String?)? recorded;
  (String, String, int)? corrected;
  BookingMealRecordModel? _record;

  @override
  Future<BookingMealsModel> load(String bookingId,
          {ApiCancellation? token}) async =>
      BookingMealsModel(plans: [
        BookingMealPlanModel(
          planId: 'plan',
          plannedDate: '2026-11-15',
          sharedAt: DateTime.utc(2026, 11, 15),
          isStale: stale,
          canRecord: !stale,
          meals: const [
            BookingMealModel(
                versionId: 'recipe',
                name: 'Cháo bí đỏ',
                mealType: 'lunch',
                servings: 1,
                ingredients: [(name: 'Bí đỏ', amount: 100, unit: 'g')],
                preparationSteps: ['Nấu chín'],
                allergens: []),
          ],
        ),
      ], records: [
        if (_record != null) _record!
      ]);

  @override
  Future<BookingMealRecordModel> record(String bookingId,
      {required String planId,
      required String recipeVersionId,
      required String mealType,
      required String outcome,
      required String idempotencyKey,
      String? note,
      ApiCancellation? token}) async {
    recorded = (planId, recipeVersionId, mealType, outcome, note);
    return _record = BookingMealRecordModel(
        id: 'record',
        planId: planId,
        plannedDate: '2026-11-15',
        recipeVersionId: recipeVersionId,
        mealType: mealType,
        outcome: outcome,
        note: note,
        recordedBy: 'caregiver',
        recordedAt: DateTime.utc(2026, 11, 15),
        timelineEventId: 'note',
        canCorrect: true);
  }

  @override
  Future<BookingMealRecordModel> correct(String bookingId,
      {required String recordId,
      required String outcome,
      required String reason,
      required int expectedRevision,
      required String idempotencyKey,
      String? note,
      ApiCancellation? token}) async {
    corrected = (recordId, reason, expectedRevision);
    return _record!;
  }
}
