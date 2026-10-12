import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/auth/auth_state.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/screens/shift_active_screen.dart';
import '../../fixtures/shift_active_fakes.dart';

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(isAuthenticated: true, userId: 'caregiver');
}

class _Shifts extends StateNotifier<List<ShiftModel>>
    implements ShiftListController {
  _Shifts(ShiftModel shift) : super([shift]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets(
        'restored active shift fits width $width at large text and cannot checkout pending tasks',
        (tester) async {
      final shift = booking(tasks: [
        const CareTaskModel(
            id: 'task',
            title:
                'Kiểm tra thông tin sức khỏe và ghi nhận kết quả vào checklist',
            isRequired: true)
      ]);
      final actions = FakeShiftActiveActions()..snapshot = shift;
      final controller = ShiftActiveController(actions, enableTimer: false)
        ..reconcile(shift);
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(ProviderScope(
          overrides: [
            authStateProvider.overrideWith(_Auth.new),
            shiftsProvider.overrideWith((ref) => _Shifts(shift)),
            shiftActiveProvider.overrideWith((ref, id) => controller)
          ],
          child: MaterialApp(
              home: MediaQuery(
                  data: MediaQueryData(
                      size: Size(width, 844),
                      textScaler: const TextScaler.linear(2)),
                  child: const ShiftActiveScreen(id: 'shift')))));
      await tester.pumpAndSettle();
      expect(find.text('Đã check-in • GPS đã được xác thực'), findsOneWidget);
      final checkout =
          find.widgetWithText(FilledButton, '✅  Hoàn thành ca & Check-out');
      await tester.ensureVisible(checkout);
      expect(tester.widget<FilledButton>(checkout).onPressed, isNull);
      expect(actions.checkouts, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
