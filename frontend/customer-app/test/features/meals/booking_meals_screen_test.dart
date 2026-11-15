import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/meals/data/models/booking_meal_model.dart';
import 'package:caresitter_customer/features/meals/data/models/booking_meal_plan_model.dart';
import 'package:caresitter_customer/features/meals/data/models/booking_meal_record_model.dart';
import 'package:caresitter_customer/features/meals/data/models/booking_meals_model.dart';
import 'package:caresitter_customer/features/meals/data/repositories/booking_meals_repository.dart';
import 'package:caresitter_customer/features/meals/presentation/screens/booking_meals_screen.dart';
import 'package:caresitter_customer/features/nutrition/data/models/meal_plan_summary_model.dart';
import 'package:caresitter_customer/features/nutrition/data/repositories/nutrition_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('family confirms share and revocation and keeps recorded meals',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final meals = _Meals();
    final nutrition = _Nutrition();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWith(_Auth.new),
        bookingMealsRepositoryProvider.overrideWithValue(meals),
        nutritionRepositoryProvider.overrideWithValue(nutrition),
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

    await tester.tap(find.text('Chia sẻ thực đơn đã lưu'));
    await tester.pumpAndSettle();
    expect(nutrition.request, ('beneficiary', DateTime.utc(2026, 11, 15)));
    expect(find.text('Thực đơn ngày 17/11/2026'), findsNothing);
    expect(find.text('Thực đơn ngày 16/11/2026'), findsNothing);
    await tester.tap(find.text('Thực đơn ngày 15/11/2026'));
    await tester.pumpAndSettle();
    expect(meals.shared, isEmpty);
    await tester.tap(find.text('Chia sẻ'));
    await tester.pumpAndSettle();
    expect(meals.shared, ['plan']);
    expect(find.text('Cháo bí đỏ'), findsOneWidget);
    expect(find.text('Bữa trưa · Ăn một phần'), findsOneWidget);

    final revoke = find.text('Thu hồi thực đơn');
    await tester.ensureVisible(revoke);
    await tester.tap(revoke);
    await tester.pumpAndSettle();
    expect(meals.revoked, isEmpty);
    await tester.tap(find.text('Thu hồi'));
    await tester.pumpAndSettle();
    expect(meals.revoked, ['2026-11-15']);
    expect(find.text('Đã thu hồi'), findsOneWidget);
    expect(find.text('Bữa trưa · Ăn một phần'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'owner', isAuthenticated: true);
}

class _NoHttp implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected HTTP call: ${invocation.memberName}');
}

class _Meals extends BookingMealsRepository {
  _Meals() : super(_NoHttp());
  final shared = <String>[];
  final revoked = <String>[];

  BookingMealPlanModel get _plan => BookingMealPlanModel(
        planId: 'plan',
        plannedDate: '2026-11-15',
        meals: const [
          BookingMealModel(
              versionId: 'recipe',
              name: 'Cháo bí đỏ',
              mealType: 'lunch',
              servings: 1,
              ingredients: [],
              preparationSteps: [],
              allergens: []),
        ],
        sharedAt: DateTime.utc(2026, 11, 15),
        revokedAt: revoked.isEmpty ? null : DateTime.utc(2026, 11, 15, 8),
        status: revoked.isEmpty ? 'shared' : 'revoked',
      );

  @override
  Future<BookingMealsModel> load(
          String bookingId, ApiCancellation token) async =>
      BookingMealsModel(
        plans: shared.isEmpty ? [] : [_plan],
        records: shared.isEmpty
            ? []
            : [
                BookingMealRecordModel(
                    id: 'record',
                    planId: 'plan',
                    plannedDate: '2026-11-15',
                    recipeVersionId: 'recipe',
                    mealType: 'lunch',
                    outcome: 'partly_eaten',
                    recordedBy: 'caregiver',
                    recordedAt: DateTime.utc(2026, 11, 15),
                    timelineEventId: 'note'),
              ],
        shareWindow: (
          beneficiaryId: 'beneficiary',
          firstDate: DateTime.utc(2026, 11, 15),
          lastDate: DateTime.utc(2026, 11, 16)
        ),
      );

  @override
  Future<BookingMealPlanModel> share(
      String bookingId, String planId, ApiCancellation token) async {
    shared.add(planId);
    return _plan;
  }

  @override
  Future<void> revoke(
      String bookingId, String plannedDate, ApiCancellation token) async {
    revoked.add(plannedDate);
  }
}

class _Nutrition extends NutritionRepository {
  _Nutrition() : super(_NoHttp());
  (String, DateTime?)? request;

  @override
  Future<List<MealPlanSummaryModel>> savedPlans(
      String id, ApiCancellation token,
      {DateTime? weekStart}) async {
    request = (id, weekStart);
    return [
      for (final (plan, date, status) in [
        ('plan', '2026-11-15', 'saved'),
        ('stale-plan', '2026-11-16', 'stale'),
        ('next-date', '2026-11-17', 'saved'),
      ])
        MealPlanSummaryModel.fromJson({
          'id': plan,
          'status': status,
          'data': {'plannedDate': date}
        }),
    ];
  }
}
