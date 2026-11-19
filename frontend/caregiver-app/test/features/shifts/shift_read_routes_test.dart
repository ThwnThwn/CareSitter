import 'dart:async';

import 'package:caregiver_app/app/router/app_router.dart';
import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/auth/auth_state.dart';
import 'package:caregiver_app/core/error/app_exception.dart';
import 'package:caregiver_app/core/realtime/care_signalr_service.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_mapper.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/data/repositories/shift_repository.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_history_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/bundled_google_fonts.dart';

void main() {
  setUp(useBundledGoogleFonts);
  tearDown(resetBundledGoogleFonts);

  Future<ProviderContainer> providers(_Repository repository) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      shiftRepositoryProvider.overrideWithValue(repository),
      careSignalRProvider.overrideWithValue(_Realtime()),
    ]);
    await container.read(authStateProvider.future);
    return container;
  }

  Future<Future<void> Function()> open(
      WidgetTester tester, _Repository repository, String location) async {
    final container = await providers(repository);
    final router = container.read(appRouterProvider);
    var closed = false;
    void dispose() {
      if (closed) return;
      closed = true;
      router.dispose();
      container.dispose();
    }

    addTearDown(dispose);
    router.go(location);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();
    return () async {
      await tester.pumpWidget(const SizedBox.shrink());
      dispose();
    };
  }

  testWidgets('detail loads an ID independently of the first list page',
      (tester) async {
    final repository = _Repository();
    final close = await open(tester, repository, '/shifts/old-shift');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Không tìm thấy ca làm việc'), findsNothing);

    repository.detail.complete(_shift('old-shift', 'completed'));
    await tester.pumpAndSettle();
    expect(repository.requestedIds, ['old-shift']);
    expect(find.text('Người nhận old-shift'), findsWidgets);
    await close();
  });

  testWidgets('detail retries a transport error and distinguishes a missing ID',
      (tester) async {
    final repository = _Repository();
    final close = await open(tester, repository, '/shifts/missing');
    repository.detail.completeError(
      const AppApiException(message: 'Mất kết nối'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải được thông tin ca.'), findsOneWidget);
    expect(find.text('Không tìm thấy ca làm việc'), findsNothing);

    repository.detail = Completer<ShiftModel>();
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    repository.detail.completeError(
      const AppApiException(message: 'Không tìm thấy', statusCode: 404),
    );
    await tester.pumpAndSettle();
    expect(repository.requestedIds, ['missing', 'missing']);
    expect(find.text('Không tìm thấy ca làm việc'), findsOneWidget);
    await close();
  });

  testWidgets('summary deep link shows backend status, time and tasks',
      (tester) async {
    final repository = _Repository();
    final close = await open(tester, repository, '/shifts/active/summary');
    repository.detail.complete(_shift('active', 'checkout_pending_review'));
    await tester.pumpAndSettle();

    expect(find.text('Đã gửi yêu cầu checkout'), findsOneWidget);
    expect(find.text('Hoàn thành ca làm việc!'), findsNothing);
    expect(find.text('1 giờ 30 phút'), findsOneWidget);
    expect(find.text('1/1 việc'), findsOneWidget);
    expect(find.text('Người nhận active'), findsOneWidget);
    expect(repository.requestedIds, ['active']);
    await close();
  });

  testWidgets('summary does not claim an ongoing booking is completed',
      (tester) async {
    final repository = _Repository();
    final close = await open(tester, repository, '/shifts/ongoing/summary');
    repository.detail.complete(_shift('ongoing', 'in_progress'));
    await tester.pumpAndSettle();
    expect(find.text('Ca chưa có tổng kết. Xem chi tiết ca'), findsOneWidget);
    expect(repository.taskReads, 0);
    await close();
  });

  testWidgets('history loads older shifts through its own pagination',
      (tester) async {
    final repository = _Repository();
    final container = await providers(repository);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: ShiftHistoryTab())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Người nhận page-1'), findsOneWidget);
    await tester.tap(find.text('Sau'));
    await tester.pumpAndSettle();
    expect(repository.historyPages, [1, 2]);
    expect(find.text('Người nhận page-2'), findsOneWidget);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Sau'))
            .onPressed,
        isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

ShiftModel _shift(String id, String status) => mapShiftFromApi({
      'id': id,
      'status': status,
      'beneficiaryName': 'Người nhận $id',
      'caregiverId': 'caregiver',
      'actualStart': '2026-11-19T08:00:00+07:00',
      'checkoutPendingReviewAt': '2026-11-19T09:30:00+07:00',
      'caregiverEarningAmount': 170000,
    });

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
      isAuthenticated: true, userId: 'caregiver-user', roles: ['CAREGIVER']);
}

class _Repository implements ShiftRepository {
  var detail = Completer<ShiftModel>();
  final requestedIds = <String>[];
  final historyPages = <int>[];
  var taskReads = 0;

  @override
  Future<List<ShiftModel>> loadAssignedAndOffers() async => [];

  @override
  Future<ShiftModel> loadShift(String id, {ApiCancellation? token}) {
    requestedIds.add(id);
    return detail.future;
  }

  @override
  Future<({List<ShiftModel> items, bool hasMore})> loadHistory(int page,
      {ApiCancellation? token}) async {
    historyPages.add(page);
    return (items: [_shift('page-$page', 'completed')], hasMore: page < 2);
  }

  @override
  Future<List<CareTaskModel>> loadCareTasks(String id,
      {ApiCancellation? token}) async {
    taskReads++;
    return [const CareTaskModel(id: 'task', title: 'Task', isCompleted: true)];
  }

  @override
  Future<String> loadCheckoutNote(String id, {ApiCancellation? token}) async =>
      'Đã hỗ trợ ăn tối';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Realtime implements CareSignalRService {
  @override
  Future<void> connect() async {}
  @override
  Stream<BookingStatusChange> get statusStream => const Stream.empty();
  @override
  Stream<BookingOfferChange> get offerStream => const Stream.empty();
  @override
  Stream<void> get onReconnected => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onTaskUpdated => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
