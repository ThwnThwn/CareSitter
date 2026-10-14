import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/screens/shift_list_screen.dart';
import '../../support/bundled_google_fonts.dart';

ShiftModel _shift(String id, String status) => ShiftModel(
    id: id,
    beneficiaryName: 'Người nhận $id',
    caregiverName: 'Hoa',
    caregiverAvatar: 'TH',
    serviceName: 'Chăm sóc tại nhà',
    status: status,
    totalPrice: 300000,
    address: 'TP. Hồ Chí Minh');

class _Shifts extends StateNotifier<List<ShiftModel>>
    implements ShiftListController {
  _Shifts()
      : super([
          _shift('active', 'in_progress'),
          _shift('offer', 'open'),
          _shift('history', 'completed')
        ]);
  var declineCalls = 0;
  bool fail = true;
  @override
  Future<void> declineBooking(String id, {String? reason}) async {
    declineCalls++;
    if (fail) throw StateError('server rejection');
    state = state.where((shift) => shift.id != id).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(useBundledGoogleFonts);
  tearDown(resetBundledGoogleFonts);
  late _Shifts shifts;
  Future<void> open(WidgetTester tester) async {
    shifts = _Shifts();
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const ShiftListScreen()),
      GoRoute(
          path: '/shifts/:id/active',
          builder: (_, state) => Scaffold(
              body: Text('Ca đang làm ${state.pathParameters['id']}'))),
      GoRoute(
          path: '/shifts/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Chi tiết ${state.pathParameters['id']}'))),
    ]);
    await tester.pumpWidget(ProviderScope(overrides: [
      shiftsProvider.overrideWith((ref) => shifts),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    });
  }

  testWidgets(
      'upcoming tab excludes invitations and opens the active shift route',
      (tester) async {
    await open(tester);
    expect(find.text('Người nhận active'), findsOneWidget);
    expect(find.text('Người nhận offer'), findsNothing);
    expect(find.text('Từ chối'), findsNothing);
    await tester.tap(find.text('Người nhận active'));
    await tester.pumpAndSettle();
    expect(find.text('Ca đang làm active'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'pending tab keeps a rejected invitation and updates after successful decline',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('Đang chờ'));
    await tester.pumpAndSettle();
    expect(find.text('Người nhận offer'), findsOneWidget);
    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();
    expect(shifts.declineCalls, 1);
    expect(find.textContaining('Chưa từ chối được ca'), findsOneWidget);
    expect(find.text('Người nhận offer'), findsOneWidget);
    shifts.fail = false;
    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();
    expect(shifts.declineCalls, 2);
    expect(find.text('Không có ca đang chờ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
