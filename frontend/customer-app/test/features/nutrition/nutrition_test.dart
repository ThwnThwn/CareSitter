import 'dart:async';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';
import 'package:caresitter_customer/features/nutrition/data/nutrition_repository.dart';
import 'package:caresitter_customer/features/nutrition/presentation/nutrition_controller.dart';
import 'package:caresitter_customer/features/nutrition/presentation/nutrition_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
      'unknown allergies remain unknown and existing structured data needs no new description',
      () async {
    final repository = _Repository();
    final c = NutritionFlowController(repository, 'first', 'owner');
    addTearDown(c.dispose);
    await settle();
    expect(c.state.health!['allergyStatus'], 'unknown');
    expect(c.state.health!['generalNote'], isNull);
    await c.assess();
    expect(repository.writes.single.data.keys,
        unorderedEquals(['expectedHealthRevision', 'idempotencyKey']));
    expect(c.state.resource!['status'], 'no_content');
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
      ..result = _resource(
          'failed', {'errorCode': 'nutrition.ai_timeout', 'retryable': true});
    final c = NutritionFlowController(repository, 'first', 'owner');
    addTearDown(c.dispose);
    await settle();
    await c.assess();
    expect(c.state.resource!['status'], 'failed');
    expect(c.state.health!['allergyStatus'], 'unknown');
    expect(repository.writes.single.route, 'nutrition-assessments');
  });

  test('lost ownership clears all server content', () async {
    final repository = _Repository();
    final c = NutritionFlowController(repository, 'first', 'owner');
    addTearDown(c.dispose);
    await settle();
    await c.assess();
    repository.writeError = _error(404);
    await c.confirm();
    expect(c.state.health, isNull);
    expect(c.state.resource, isNull);
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
    expect(c.state.resource, isNull);
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
    expect(c.state.resource!['status'], 'stale');
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
    final old = container.read(nutritionFlowProvider('first').notifier);
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
      expect(find.text('Dị ứng thực phẩm'), findsOneWidget);
      final check = find.widgetWithText(FilledButton, 'Kiểm tra thông tin');
      await tester.scrollUntilVisible(check, 250);
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(find.text('Chưa có công thức đã duyệt cho nhu cầu này'),
          findsOneWidget);
      expect(find.text('Fixture recipe'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

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
    await tester.ensureVisible(find.text('Lưu ý và hướng dẫn hiện có'));
    await tester.tap(find.text('Lưu ý và hướng dẫn hiện có'));
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

Map<String, dynamic> _resource(String status, Map<String, dynamic> data) =>
    {'id': 'resource', 'status': status, 'healthRevision': 7, 'data': data};
DioException _error(int status, {String? code}) => DioException(
    requestOptions: RequestOptions(path: '/'),
    response: Response(
        requestOptions: RequestOptions(path: '/'),
        statusCode: status,
        data: {'title': code, 'detail': 'Yêu cầu chưa thành công'}));

class _UnusedDio implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository extends NutritionRepository {
  _Repository() : super(_UnusedDio(), _UnusedDio());
  Map<String, dynamic> result = _resource('no_content', {
    'decision': {'state': 'no_content'},
    'meals': []
  });
  DioException? writeError, patchError;
  Completer<Map<String, dynamic>>? pending;
  final writes = <({String route, Map<String, dynamic> data})>[];
  final tokens = <CancelToken>[];
  final patches = <Map<String, dynamic>>[];
  @override
  bool get isConfigured => true;
  @override
  Future<Map<String, dynamic>> capabilities(CancelToken token) async => {
        'enabled': true,
        'assessmentsEnabled': true,
        'recommendationsEnabled': true
      };
  @override
  Future<Map<String, dynamic>> health(String id, CancelToken token) async => {
        'revision': 7,
        'allergyStatus': 'unknown',
        'generalNote': null,
        'healthHistory': {
          'nutrition': {'schemaVersion': 1, 'conditionsStatus': 'reported_none'}
        }
      };
  @override
  Future<Map<String, dynamic>> write(String id, String route,
      Map<String, dynamic> data, CancelToken token) async {
    writes.add((route: route, data: data));
    tokens.add(token);
    if (writeError != null) throw writeError!;
    return pending != null ? await pending!.future : result;
  }

  @override
  Future<Map<String, dynamic>> patch(String id, int revision,
      Map<String, dynamic> changes, CancelToken token) async {
    patches.add(changes);
    if (patchError != null) throw patchError!;
    return {...await health(id, token), 'revision': 8, ...changes};
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
