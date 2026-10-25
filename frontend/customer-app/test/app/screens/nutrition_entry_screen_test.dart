import 'dart:async';

import 'package:caresitter_customer/app/screens/nutrition_entry_screen.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/data/models/beneficiary_model.dart';
import 'package:caresitter_customer/features/beneficiary/data/repositories/beneficiary_repository.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart'
    show BeneficiaryStore, beneficiaryStoreProvider;
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_load_state_controller.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'package:caresitter_customer/features/nutrition/data/models/health_profile_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/meal_plan_summary_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_capabilities_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_resource_model.dart';
import 'package:caresitter_customer/features/nutrition/data/repositories/nutrition_repository.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_health_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('shows profiles without waiting for addresses', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(_Auth.new),
        beneficiaryRepositoryProvider.overrideWithValue(
          _ImmediateBeneficiaryRepository(),
        ),
        addressStoreProvider.overrideWith(_PendingAddresses.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const NutritionEntryScreen(),
        ),
      ),
    );
    await _flush(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Trần Thị Loan'), findsOneWidget);
  });

  testWidgets('opens nutrition inline after selecting a profile',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/nutrition',
      routes: [
        GoRoute(
          path: '/nutrition',
          builder: (_, __) => const NutritionEntryScreen(),
        ),
        GoRoute(
          path: '/beneficiaries/:id/nutrition',
          builder: (_, state) => Scaffold(
            body: Text('nutrition:${state.pathParameters['id']}'),
          ),
        ),
        GoRoute(
          path: '/beneficiaries/create',
          builder: (_, __) => const SizedBox(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_Auth.new),
          beneficiaryStoreProvider.overrideWith(_Beneficiaries.new),
          beneficiaryLoadStateProvider.overrideWith(_LoadedState.new),
          nutritionRepositoryProvider.overrideWithValue(_NutritionRepository()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('nutrition-beneficiary-loan')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thực đơn cho Trần Thị Loan'), findsOneWidget);
    expect(find.byType(NutritionHealthForm), findsNothing);
    await tester.tap(find.byTooltip('Cập nhật thông tin dinh dưỡng'));
    await tester.pumpAndSettle();
    expect(find.text('Cập nhật thông tin cho Trần Thị Loan'), findsOneWidget);
    expect(find.byType(NutritionHealthForm), findsOneWidget);
  });

  testWidgets('always opens the profile picker before a saved menu',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _NutritionRepository(withSavedPlan: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_Auth.new),
          beneficiaryStoreProvider.overrideWith(_Beneficiaries.new),
          beneficiaryLoadStateProvider.overrideWith(_LoadedState.new),
          nutritionRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: const NutritionEntryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Chọn người cần lập thực đơn'), findsOneWidget);
    expect(find.text('Thực đơn cho Trần Thị Loan'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('nutrition-beneficiary-loan')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thực đơn cho Trần Thị Loan'), findsOneWidget);

    await tester.ensureVisible(find.text('23'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('23'));
    await tester.pumpAndSettle();
    expect(repository.lastReadRoute, 'meal-plans/plan-2');

    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Súp bí đỏ'), findsOneWidget);
    expect(find.byType(NutritionHealthForm), findsNothing);
    expect(find.byTooltip('Trở về chọn người'), findsOneWidget);

    await tester.tap(find.byTooltip('Trở về chọn người'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn người cần lập thực đơn'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('nutrition-beneficiary-loan')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cập nhật thông tin dinh dưỡng'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(NutritionHealthForm), findsOneWidget);
  });
}

Future<void> _flush(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.pump();
  }
}

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'owner', isAuthenticated: true);
}

class _PendingAddresses extends AddressStore {
  @override
  Future<List<AddressModel>> build() => Completer<List<AddressModel>>().future;
}

class _ImmediateBeneficiaryRepository implements BeneficiaryRepository {
  @override
  Future<List<Map<String, dynamic>>> getBeneficiaries() async => [
        {
          'Id': 'loan',
          'FullName': 'Trần Thị Loan',
          'RelationshipToCustomer': 'Mẹ',
        }
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Beneficiaries extends BeneficiaryStore {
  @override
  List<BeneficiaryModel> build() => [
        BeneficiaryModel(
          id: 'loan',
          name: 'Trần Thị Loan',
          dateOfBirth: DateTime(1956, 1, 1),
          relation: 'Mẹ',
          avatarInitial: 'TL',
          condition: '',
          careLevel: '',
          notes: '',
          address: '',
        ),
      ];
}

class _LoadedState extends BeneficiaryLoadStateController {
  @override
  AsyncValue<void> build() => const AsyncData(null);
}

class _NutritionRepository extends NutritionRepository {
  _NutritionRepository({this.withSavedPlan = false}) : super(_UnusedDio());

  final bool withSavedPlan;
  String? lastReadRoute;

  @override
  bool get isConfigured => true;

  @override
  Future<NutritionCapabilitiesModel> capabilities(
          ApiCancellation token) async =>
      const NutritionCapabilitiesModel(
        enabled: true,
        assessmentsEnabled: true,
        recommendationsEnabled: true,
      );

  @override
  Future<HealthProfileModel> health(String id, ApiCancellation token) async =>
      HealthProfileModel.fromJson(_readyHealth());

  @override
  Future<List<MealPlanSummaryModel>> savedPlans(
      String id, ApiCancellation token) async {
    if (!withSavedPlan) return const [];
    return [
      MealPlanSummaryModel.fromJson({
        'id': 'plan-1',
        'status': 'saved',
        'data': {'plannedDate': '2026-10-22'},
      }),
      MealPlanSummaryModel.fromJson({
        'id': 'plan-2',
        'status': 'saved',
        'data': {'plannedDate': '2026-10-23'},
      }),
    ];
  }

  @override
  Future<NutritionResourceModel> read(
      String id, String route, ApiCancellation token) async {
    lastReadRoute = route;
    final secondPlan = route == 'meal-plans/plan-2';
    return NutritionResourceModel.fromJson({
      'id': secondPlan ? 'plan-2' : 'plan-1',
      'status': 'saved',
      'healthRevision': 7,
      'data': {
        'plannedDate': secondPlan ? '2026-10-23' : '2026-10-22',
        'decision': {'state': 'suggested'},
        'meals': [
          {
            'mealType': 'breakfast',
            'name': secondPlan ? 'Súp bí đỏ' : 'Cháo yến mạch',
            'servings': 1,
          },
        ],
      },
    });
  }
}

class _UnusedDio implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _readyHealth() => {
      'revision': 7,
      'allergyStatus': 'reported_none',
      'healthHistory': {
        'nutrition': {
          'schemaVersion': 1,
          'conditionsStatus': 'reported_none',
          'medicationsStatus': 'reported_none',
          'feedingRoute': 'oral',
          'swallowingStatus': 'normal',
          'fluidRestriction': 'none',
          'electrolyteRestriction': 'none',
        },
      },
    };
