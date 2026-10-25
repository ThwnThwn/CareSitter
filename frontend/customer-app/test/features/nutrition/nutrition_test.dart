import 'package:caresitter_customer/features/nutrition/data/models/health_profile_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_resource_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_capabilities_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/meal_plan_summary_model.dart';
import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'dart:async';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';
import 'package:caresitter_customer/features/nutrition/data/repositories/nutrition_repository.dart';
import 'package:caresitter_customer/features/nutrition/presentation/controllers/nutrition_controller.dart';
import 'package:caresitter_customer/features/nutrition/presentation/screens/nutrition_screen.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_expansion_card.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_health_fields.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_health_form.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_status_field.dart';
import 'package:caresitter_customer/features/nutrition/domain/nutrition_personalization_rules.dart';
import 'package:caresitter_customer/features/nutrition/domain/nutrition_assessment_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('assessment start policy allows only actionable failed retries', () {
    expect(
        NutritionAssessmentRules.canStart(
            loading: false,
            restoringPlan: false,
            resourceStatus: 'failed',
            retryable: true,
            retryAllowed: true),
        isTrue);
    expect(
        NutritionAssessmentRules.canStart(
            loading: false,
            restoringPlan: false,
            resourceStatus: 'failed',
            retryable: true,
            retryAllowed: false),
        isFalse);
    expect(
        NutritionAssessmentRules.canStart(
            loading: true,
            restoringPlan: false,
            resourceStatus: null,
            retryable: false,
            retryAllowed: false),
        isFalse);
  });

  testWidgets('status field falls back to the first declared option',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NutritionStatusField(
          label: 'Chế độ ăn',
          value: 'legacy-value',
          options: const {'regular': 'Ăn thông thường'},
          enabled: true,
          onChanged: (_) {},
        ),
      ),
    ));

    expect(find.text('Ăn thông thường'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('personalized nutrition requires all seven health declarations', () {
    final unknown = NutritionPersonalizationRules.evaluate(
        allergyStatus: 'unknown',
        allergies: const [],
        conditionStatus: 'unknown',
        chronicConditions: const [],
        medicationsStatus: 'unknown',
        medications: const [],
        feedingRoute: 'unknown',
        swallowingStatus: 'unknown',
        fluidRestriction: 'unknown',
        electrolyteRestriction: 'unknown');
    expect(unknown.isReady, isFalse);
    expect(unknown.missingFields, hasLength(3));
    expect(unknown.totalIssueCount, 7);

    final incomplete = NutritionPersonalizationRules.evaluate(
        allergyStatus: 'reported_present',
        allergies: const [],
        conditionStatus: 'reported_present',
        chronicConditions: const [],
        medicationsStatus: 'reported_none',
        medications: const [],
        feedingRoute: 'oral',
        swallowingStatus: 'normal',
        fluidRestriction: 'none',
        electrolyteRestriction: 'none');
    expect(incomplete.isReady, isFalse);
    expect(incomplete.missingFields,
        containsAll(['Ghi rõ thực phẩm gây dị ứng', 'Ghi rõ bệnh lý đã biết']));

    final ready = NutritionPersonalizationRules.evaluate(
        allergyStatus: 'reported_none',
        allergies: const [],
        conditionStatus: 'reported_present',
        chronicConditions: const ['Tăng huyết áp'],
        medicationsStatus: 'reported_none',
        medications: const [],
        feedingRoute: 'oral',
        swallowingStatus: 'normal',
        fluidRestriction: 'none',
        electrolyteRestriction: 'none');
    expect(ready.isReady, isTrue);
  });

  test('personalized nutrition detects contradictory none declarations', () {
    final readiness = NutritionPersonalizationRules.evaluate(
        allergyStatus: 'reported_none',
        allergies: const ['Tôm'],
        conditionStatus: 'reported_none',
        chronicConditions: const ['Tăng huyết áp'],
        medicationsStatus: 'reported_none',
        medications: const [
          {'name': 'Thuốc A'}
        ],
        feedingRoute: 'oral',
        swallowingStatus: 'normal',
        fluidRestriction: 'none',
        electrolyteRestriction: 'none');

    expect(readiness.isReady, isFalse);
    expect(readiness.totalIssueCount, 3);
    expect(
        readiness.missingFields, contains('Làm rõ thông tin dị ứng mâu thuẫn'));
    expect(readiness.missingFields,
        contains('Làm rõ thông tin bệnh lý mâu thuẫn'));
    expect(
        readiness.missingFields, contains('Làm rõ thông tin thuốc mâu thuẫn'));
  });

  testWidgets(
      'assessment remains available when health declarations are missing',
      (tester) async {
    final repository = _Repository()
      ..healthOverride = {
        'revision': 7,
        'allergyStatus': 'unknown',
        'generalNote': null,
        'healthHistory': {
          'nutrition': {'schemaVersion': 1, 'conditionsStatus': 'unknown'}
        }
      };
    await tester.pumpWidget(ProviderScope(
        overrides: [
          nutritionRepositoryProvider.overrideWithValue(repository),
          authStateProvider.overrideWith(_Auth.new),
          beneficiaryStoreProvider.overrideWith(_Beneficiaries.new),
        ],
        child:
            const MaterialApp(home: NutritionScreen(beneficiaryId: 'first'))));
    await tester.pumpAndSettle();
    await _openProfileEditor(tester);
    final check = find.widgetWithText(FilledButton, 'Kiểm tra thông tin');
    await tester.scrollUntilVisible(check, 250);
    expect(tester.widget<FilledButton>(check).onPressed, isNotNull);
  });

  testWidgets(
      'structured restriction is saved sparsely and survives a failed save',
      (tester) async {
    final repository = _Repository()..patchError = _error(503);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          nutritionRepositoryProvider.overrideWithValue(repository),
          authStateProvider.overrideWith(_Auth.new),
          beneficiaryStoreProvider.overrideWith(_Beneficiaries.new),
        ],
        child:
            const MaterialApp(home: NutritionScreen(beneficiaryId: 'first'))));
    await tester.pumpAndSettle();
    await _openProfileEditor(tester);
    final section = find.text('Thuốc và nhu cầu ăn uống');
    await Scrollable.ensureVisible(
      tester.element(section),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(section);
    await tester.pumpAndSettle();
    final route = find.byKey(const ValueKey('nutrition-feedingRoute'));
    await tester.ensureVisible(route);
    await tester.tap(route);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ăn qua ống').last);
    await tester.pumpAndSettle();
    final save =
        find.widgetWithText(OutlinedButton, 'Lưu phần thông tin đã cập nhật');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.patches.single, {
      'nutritionProfile': {'feedingRoute': 'tube'}
    });
    await tester.ensureVisible(route);
    expect(find.text('Ăn qua ống'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'dietary pattern and nutrition goal are saved in one profile patch',
      (tester) async {
    Map<String, dynamic>? changes;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListView(children: [
      NutritionHealthForm(
          health: HealthProfileModel.fromJson(const {
            'allergyStatus': 'reported_none',
            'healthHistory': {
              'nutrition': {
                'schemaVersion': 1,
                'conditionsStatus': 'reported_none'
              }
            }
          }),
          enabled: true,
          onDirtyChanged: (_) {},
          onSave: (value) => changes = value),
    ]))));

    expect(find.byType(NutritionExpansionCard), findsNWidgets(3));

    final preferences = find.text('Kiểu ăn và mục tiêu');
    await tester.ensureVisible(preferences);
    await tester.tap(preferences);
    await tester.pumpAndSettle();

    final dietaryPattern =
        find.byKey(const ValueKey('nutrition-dietaryPattern'));
    await tester.ensureVisible(dietaryPattern);
    await tester.tap(dietaryPattern);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ăn chay').last);
    await tester.pumpAndSettle();

    final nutritionGoal = find.byKey(const ValueKey('nutrition-nutritionGoal'));
    await tester.ensureVisible(nutritionGoal);
    await tester.tap(nutritionGoal);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tăng cân').last);
    await tester.pumpAndSettle();

    final save =
        find.widgetWithText(OutlinedButton, 'Lưu phần thông tin đã cập nhật');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(changes, {
      'nutritionProfile': {
        'dietaryPattern': 'vegetarian',
        'nutritionGoal': 'gain'
      }
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing medication keeps existing instructions and dates',
      (tester) async {
    Map<String, dynamic>? changes;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListView(children: [
      NutritionHealthFields(health: const {
        'medications': [
          {
            'name': 'Thuốc đã lưu',
            'dosage': 'Thông tin cũ',
            'schedule': 'Theo đơn',
            'instruction': 'Ghi chú đã lưu',
            'start_date': '2026-10-01',
            'is_active': true
          }
        ]
      }, enabled: true, onChanged: (value) => changes = value),
    ]))));
    await tester.tap(find.text('Thuốc và nhu cầu ăn uống'));
    await tester.pumpAndSettle();
    final name =
        find.widgetWithText(TextField, 'Tên thuốc theo thông tin hiện có');
    await tester.ensureVisible(name);
    await tester.enterText(name, 'Tên đã đối chiếu');
    final medication = (changes!['medications'] as List).single as Map;
    expect(medication['name'], 'Tên đã đối chiếu');
    expect(medication['instruction'], 'Ghi chú đã lưu');
    expect(medication['start_date'], '2026-10-01');
    expect(medication['schedule'], 'Theo đơn');
    expect(medication['dosage'], 'Thông tin cũ');
    expect(changes!.containsKey('nutritionProfile'), isFalse);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets(
        'expanded structured health fields fit width $width at large text',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: Scaffold(
              body: ListView(children: [
            NutritionHealthFields(
                health: const {}, enabled: true, onChanged: (_) {})
          ]))));
      await tester.tap(find.text('Thuốc và nhu cầu ăn uống'));
      await tester.pumpAndSettle();
      for (final field in [
        'medicationsStatus',
        'feedingRoute',
        'swallowingStatus',
        'fluidRestriction',
        'electrolyteRestriction'
      ]) {
        final choice = find.byKey(ValueKey('nutrition-$field'));
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  test(
      'unknown allergies remain unknown and existing structured data needs no new description',
      () async {
    final repository = _Repository()..healthOverride = _unknownHealth();
    final c = NutritionFlowController(repository, 'first', 'owner');
    addTearDown(c.dispose);
    await settle();
    expect(c.view.health!['allergyStatus'], 'unknown');
    expect(c.view.health!['generalNote'], isNull);
    await c.assess();
    expect(repository.writes.single.data.keys,
        unorderedEquals(['expectedHealthRevision', 'idempotencyKey']));
    expect(c.view.resource!['status'], 'no_content');
  });

  test(
      'transport retry uses same idempotency key while explicit failed-analysis retry gets a new key',
      () async {
    final repository = _Repository()..writeError = _error(503);
    final c = NutritionFlowController(repository, 'first', 'owner');
    addTearDown(c.dispose);
    await settle();
    await c.assess();
    repository.writeError = null;
    await c.assess();
    expect(repository.writes[0].data['idempotencyKey'],
        repository.writes[1].data['idempotencyKey']);
    await c.assess(retryFailed: true);
    expect(repository.writes[2].data['idempotencyKey'],
        isNot(repository.writes[1].data['idempotencyKey']));
  });

  test('AI failure retains source and cannot become a healthy profile',
      () async {
    final repository = _Repository()
      ..healthOverride = _unknownHealth()
      ..result = _resource(
          'failed', {'errorCode': 'nutrition.ai_timeout', 'retryable': true});
    final c = NutritionFlowController(repository, 'first', 'owner');
    addTearDown(c.dispose);
    await settle();
    await c.assess();
    expect(c.view.resource!['status'], 'failed');
    expect(c.view.health!['allergyStatus'], 'unknown');
    expect(repository.writes.single.route, 'nutrition-assessments');
  });

  testWidgets('AI credential failure is explained precisely on screen',
      (tester) async {
    final repository = _Repository()
      ..result = _resource('failed', {
        'errorCode': 'nutrition.ai_authentication_failed',
        'retryable': false
      });
    await tester.pumpWidget(ProviderScope(
        overrides: [
          nutritionRepositoryProvider.overrideWithValue(repository),
          authStateProvider.overrideWith(_Auth.new),
          beneficiaryStoreProvider.overrideWith(_Beneficiaries.new),
        ],
        child:
            const MaterialApp(home: NutritionScreen(beneficiaryId: 'first'))));
    await tester.pumpAndSettle();
    await _openProfileEditor(tester);
    final check = find.widgetWithText(FilledButton, 'Kiểm tra thông tin');
    await tester.scrollUntilVisible(check, 250);
    await tester.tap(check);
    await tester.pumpAndSettle();
    final message = find.textContaining('API key của dịch vụ AI không hợp lệ');
    await tester.scrollUntilVisible(message, 150,
        scrollable: find.byType(Scrollable).first);
    expect(message, findsOneWidget);
  });

  test('lost ownership clears all server content', () async {
    final repository = _Repository();
    final c = NutritionFlowController(repository, 'first', 'owner');
    addTearDown(c.dispose);
    await settle();
    await c.assess();
    repository.writeError = _error(404);
    await c.confirm();
    expect(c.view.health, isNull);
    expect(c.view.resource, isNull);
  });

  test('late response after cancellation cannot restore an old result',
      () async {
    final repository = _Repository()
      ..pending = Completer<Map<String, dynamic>>();
    final c = NutritionFlowController(repository, 'first', 'owner');
    addTearDown(c.dispose);
    await settle();
    final request = c.assess();
    c.suspend();
    expect(repository.tokens.last.isCancelled, isTrue);
    repository.pending!.complete(_resource('suggested', {'meals': []}));
    await request;
    expect(c.view.resource, isNull);
  });

  test('resuming an already loaded nutrition flow does not reload health',
      () async {
    final repository = _Repository();
    final c = NutritionFlowController(repository, 'first', 'owner');
    addTearDown(c.dispose);
    await settle();

    expect(repository.healthCalls, 1);
    c.suspend();
    c.resume();
    await settle();

    expect(repository.healthCalls, 1);
  });

  test('loading saved plans does not put the nutrition page in loading state',
      () async {
    final repository = _Repository()
      ..plansPending = Completer<List<MealPlanSummaryModel>>();
    final c = NutritionFlowController(repository, 'first', 'owner');
    addTearDown(c.dispose);
    await settle();

    final request = c.plans();
    await Future<void>.delayed(Duration.zero);
    expect(c.view.loading, isFalse);

    repository.plansPending!.complete(const []);
    await request;
  });

  test('selected plan date and request state belong to the flow controller',
      () async {
    final date = DateTime(2026, 11, 3);
    final plan = NutritionResourceModel.fromJson(_resource('saved', {
      'decision': {'state': 'suggested'},
      'plannedDate': '2026-11-03',
      'meals': [],
    }));
    final pendingPlans = Completer<List<MealPlanSummaryModel>>();
    final repository = _Repository()..openedPlans[plan.id] = plan;
    final c = NutritionFlowController(repository, 'first', 'owner');
    addTearDown(c.dispose);
    await settle();
    repository.plansPending = pendingPlans;

    final request = c.openPlanForDate(date);
    await Future<void>.delayed(Duration.zero);
    expect(c.view.selectedDate, date);
    expect(c.view.dateLoading, isTrue);

    pendingPlans.complete([MealPlanSummaryModel.fromJson(plan.toJson())]);
    expect(await request, isTrue);
    expect(c.view.dateLoading, isFalse);
    expect(c.view.dateError, isNull);
    expect(c.view.resource?.id, plan.id);
  });

  test('profile or catalog conflict marks previous recommendation stale',
      () async {
    final repository = _Repository();
    final c = NutritionFlowController(repository, 'first', 'owner');
    addTearDown(c.dispose);
    await settle();
    await c.assess();
    repository.writeError = _error(409, code: 'nutrition.profile_changed');
    await c.save();
    expect(c.view.resource!['status'], 'stale');
  });

  test('switching session disposes its controller and cancels in-flight work',
      () async {
    final repository = _Repository();
    final auth = _Auth();
    final container = ProviderContainer(overrides: [
      nutritionRepositoryProvider.overrideWithValue(repository),
      authStateProvider.overrideWith(() => auth),
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    final subscription =
        container.listen(nutritionFlowProvider('first'), (previous, next) {});
    addTearDown(subscription.close);
    await settle();
    final old = container.read(nutritionControllerProvider('first').notifier);
    repository.pending = Completer<Map<String, dynamic>>();
    final request = old.assess();
    auth.set(const AuthState.initial());
    await settle();
    expect(repository.tokens.any((t) => t.isCancelled), isTrue);
    repository.pending!.complete(_resource('suggested', {'meals': []}));
    await request;
    expect(container.read(nutritionFlowProvider('first')).health, isNull);
    expect(container.read(nutritionFlowProvider('first')).resource, isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets(
        'nutrition empty content and optional notes fit width $width with large text',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository();
      await tester.pumpWidget(ProviderScope(
          overrides: [
            nutritionRepositoryProvider.overrideWithValue(repository),
            authStateProvider.overrideWith(_Auth.new),
            beneficiaryStoreProvider.overrideWith(_Beneficiaries.new),
          ],
          child: MaterialApp(
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!),
              home: const NutritionScreen(beneficiaryId: 'first'))));
      await tester.pumpAndSettle();
      await _openProfileEditor(tester);
      await tester.scrollUntilVisible(find.text('Dị ứng thực phẩm'), 150,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Dị ứng thực phẩm'), findsOneWidget);
      final check = find.widgetWithText(FilledButton, 'Kiểm tra thông tin');
      await tester.scrollUntilVisible(check, 250);
      await tester.pumpAndSettle();
      await tester.ensureVisible(check);
      await tester.pumpAndSettle();
      await tester.tap(check);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.text('Chưa có dữ liệu thực đơn để gợi ý'), 150,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Chưa có dữ liệu thực đơn để gợi ý'), findsOneWidget);
      expect(find.textContaining('Kho thực đơn hiện chưa có món đủ dữ liệu'),
          findsOneWidget);
      expect(find.text('Fixture recipe'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('nutrition distinguishes no matching menu from an empty catalog',
      (tester) async {
    final repository = _Repository()
      ..result = _resource('no_match', {
        'decision': {'state': 'no_match'},
        'meals': []
      });
    await tester.pumpWidget(ProviderScope(
        overrides: [
          nutritionRepositoryProvider.overrideWithValue(repository),
          authStateProvider.overrideWith(_Auth.new),
          beneficiaryStoreProvider.overrideWith(_Beneficiaries.new),
        ],
        child:
            const MaterialApp(home: NutritionScreen(beneficiaryId: 'first'))));
    await tester.pumpAndSettle();
    await _openProfileEditor(tester);
    final check = find.widgetWithText(FilledButton, 'Kiểm tra thông tin');
    await tester.scrollUntilVisible(check, 250);
    await tester.tap(check);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Chưa có thực đơn phù hợp'), 150,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Chưa có thực đơn phù hợp'), findsOneWidget);
    expect(find.textContaining('Chưa tìm được món đáp ứng các yêu cầu'),
        findsOneWidget);
    expect(find.text('Chưa có dữ liệu thực đơn để gợi ý'), findsNothing);
  });

  testWidgets('nutrition calendar remains selectable without a saved plan',
      (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          nutritionRepositoryProvider.overrideWithValue(repository),
          authStateProvider.overrideWith(_Auth.new),
          beneficiaryStoreProvider.overrideWith(_Beneficiaries.new),
        ],
        child:
            const MaterialApp(home: NutritionScreen(beneficiaryId: 'first'))));
    await tester.pumpAndSettle();

    expect(find.text('Lịch thực đơn'), findsOneWidget);
    final today = DateUtils.dateOnly(DateTime.now());
    final selectedDate = today.weekday == DateTime.sunday
        ? today.subtract(const Duration(days: 1))
        : today.add(const Duration(days: 1));
    final day = find.text('${selectedDate.day}').last;
    await tester.ensureVisible(day);
    await tester.tap(day);
    await tester.pumpAndSettle();

    final dateLabel =
        '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}';
    expect(find.text('Chưa có thực đơn cho ngày $dateLabel'), findsOneWidget);
    expect(
        find.text(
            'Dùng hồ sơ hiện có để tạo thực đơn hoặc chọn một ngày khác.'),
        findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'failed analysis preserves draft notes and disables stale analysis until saved',
      (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          nutritionRepositoryProvider.overrideWithValue(repository),
          authStateProvider.overrideWith(_Auth.new),
          beneficiaryStoreProvider.overrideWith(_Beneficiaries.new),
        ],
        child:
            const MaterialApp(home: NutritionScreen(beneficiaryId: 'first'))));
    await tester.pumpAndSettle();
    await _openProfileEditor(tester);
    final notesSection = find.text('Lưu ý và hướng dẫn hiện có');
    await Scrollable.ensureVisible(tester.element(notesSection),
        alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(notesSection);
    await tester.pumpAndSettle();
    final note =
        find.widgetWithText(TextField, 'Lưu ý sức khỏe / triệu chứng chưa rõ');
    await tester.ensureVisible(note);
    await tester.enterText(note, 'Nội dung gia đình đang nhập');
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Kiểm tra thông tin'))
            .onPressed,
        isNull);
    repository.patchError = _error(503);
    final save =
        find.widgetWithText(OutlinedButton, 'Lưu phần thông tin đã cập nhật');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.patches.single['generalNote'],
        'Nội dung gia đình đang nhập');
    final notes = find.text('Lưu ý và hướng dẫn hiện có');
    await tester.scrollUntilVisible(notes, -200,
        scrollable: find.byType(Scrollable).first);
    if (note.evaluate().isEmpty) {
      await tester.tap(notes);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(note);
    expect(tester.widget<TextField>(note).controller!.text,
        'Nội dung gia đình đang nhập');
  });
}

Future<void> _openProfileEditor(WidgetTester tester) async {
  final editButton = find.byTooltip('Cập nhật thông tin dinh dưỡng');
  if (editButton.evaluate().isNotEmpty) {
    await tester.tap(editButton);
    await tester.pumpAndSettle();
  }
}

Map<String, dynamic> _resource(String status, Map<String, dynamic> data) =>
    {'id': 'resource', 'status': status, 'healthRevision': 7, 'data': data};
AppApiException _error(int status, {String? code}) => AppApiException(
    message: 'Yêu cầu chưa thành công',
    statusCode: status,
    code: code,
    details: {'title': code, 'detail': 'Yêu cầu chưa thành công'});

class _UnusedDio implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository extends NutritionRepository {
  _Repository() : super(_UnusedDio());
  Map<String, dynamic> result = _resource('no_content', {
    'decision': {'state': 'no_content'},
    'meals': []
  });
  AppApiException? writeError, patchError;
  Map<String, dynamic>? healthOverride;
  Completer<Map<String, dynamic>>? pending;
  Completer<List<MealPlanSummaryModel>>? plansPending;
  final openedPlans = <String, NutritionResourceModel>{};
  final writes = <({String route, Map<String, dynamic> data})>[];
  final tokens = <ApiCancellation>[];
  final patches = <Map<String, dynamic>>[];
  int healthCalls = 0;
  @override
  bool get isConfigured => true;
  @override
  Future<NutritionCapabilitiesModel> capabilities(
          ApiCancellation token) async =>
      const NutritionCapabilitiesModel(
          enabled: true,
          assessmentsEnabled: true,
          recommendationsEnabled: true);
  @override
  Future<HealthProfileModel> health(String id, ApiCancellation token) async {
    healthCalls++;
    return HealthProfileModel.fromJson(healthOverride ?? _readyHealth());
  }

  @override
  Future<List<MealPlanSummaryModel>> savedPlans(
      String id, ApiCancellation token) async {
    return plansPending == null
        ? const <MealPlanSummaryModel>[]
        : await plansPending!.future;
  }

  @override
  Future<NutritionResourceModel> read(
      String id, String route, ApiCancellation token) async {
    if (route.startsWith('meal-plans/')) {
      final plan = openedPlans[route.substring('meal-plans/'.length)];
      if (plan != null) return plan;
    }
    throw StateError('Unexpected read: $route');
  }

  @override
  Future<NutritionResourceModel> write(String id, String route,
      Map<String, dynamic> data, ApiCancellation token) async {
    writes.add((route: route, data: data));
    tokens.add(token);
    if (writeError != null) throw writeError!;
    return NutritionResourceModel.fromJson(
        pending != null ? await pending!.future : result);
  }

  @override
  Future<HealthProfileModel> patch(String id, int revision,
      Map<String, dynamic> changes, ApiCancellation token) async {
    patches.add(changes);
    if (patchError != null) throw patchError!;
    return HealthProfileModel.fromJson(
        {...await health(id, token), 'revision': 8, ...changes});
  }
}

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'owner', isAuthenticated: true);
  void set(AuthState value) => state = AsyncData(value);
}

class _Beneficiaries extends BeneficiaryStore {
  @override
  List<BeneficiaryModel> build() => [];
}

Map<String, dynamic> _readyHealth() => {
      'revision': 7,
      'allergyStatus': 'reported_none',
      'generalNote': null,
      'healthHistory': {
        'nutrition': {
          'schemaVersion': 1,
          'conditionsStatus': 'reported_none',
          'medicationsStatus': 'reported_none',
          'feedingRoute': 'oral',
          'swallowingStatus': 'normal',
          'fluidRestriction': 'none',
          'electrolyteRestriction': 'none',
        }
      }
    };

Map<String, dynamic> _unknownHealth() => {
      'revision': 7,
      'allergyStatus': 'unknown',
      'generalNote': null,
      'healthHistory': {
        'nutrition': {'schemaVersion': 1, 'conditionsStatus': 'reported_none'}
      }
    };
