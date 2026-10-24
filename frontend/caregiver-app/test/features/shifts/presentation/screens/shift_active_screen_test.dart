import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/auth/auth_state.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/screens/shift_active_screen.dart';
import 'package:caregiver_app/core/widgets/beneficiary_avatar.dart';
import 'package:caregiver_app/core/widgets/app_toast.dart';
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
  for (final (width, textScale) in [
    (320.0, 2.0),
    (390.0, 1.0),
    (390.0, 2.0),
  ]) {
    testWidgets(
        'Stitch 2 active shift fits width $width at ${textScale}x text and blocks premature checkout',
        (tester) async {
      final shift = booking(tasks: [
        const CareTaskModel(
            id: 'task',
            title:
                'Kiểm tra thông tin sức khỏe và ghi nhận kết quả vào checklist',
            isRequired: true,
            requiresPhoto: true),
        const CareTaskModel(
          id: 'reminder',
          title: 'Nhắc lịch sinh hoạt & uống thuốc',
          description: 'Người được chăm sóc tự thực hiện việc dùng thuốc.',
          isRequired: true,
        ),
        const CareTaskModel(
          id: 'suggested',
          title: 'Bầu bạn & Trò chuyện tâm tình',
          source: 'CAREGIVER_AD_HOC',
        ),
      ]).copyWith(beneficiaryAge: 49, beneficiaryGender: 'female');
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
                      textScaler: TextScaler.linear(textScale)),
                  child: const ShiftActiveScreen(id: 'shift')))));
      await tester.pumpAndSettle();
      expect(find.text('Checklist công việc'), findsOneWidget);
      expect(find.text('Theo hợp đồng'), findsOneWidget);
      expect(find.text('0 / 3'), findsOneWidget);
      expect(find.byTooltip('Báo cáo khẩn cấp'), findsOneWidget);
      expect(find.text('Minh chứng'), findsNWidgets(3));
      expect(find.text('Hoàn thành'), findsNWidgets(3));
      expect(find.text('Bỏ qua'), findsNWidgets(3));
      expect(find.text('Phi y tế'), findsNothing);
      expect(find.text('Đề xuất thêm'), findsOneWidget);
      expect(find.text('Ghi chú ca'), findsOneWidget);
      expect(find.text('Trợ giúp nhanh'), findsOneWidget);
      expect(find.byType(BeneficiaryAvatar), findsOneWidget);
      final completeTask = find.widgetWithText(TextButton, 'Hoàn thành').first;
      expect(tester.widget<TextButton>(completeTask).onPressed, isNotNull);
      expect(find.text('Cần ảnh'), findsNothing);
      final portrait = tester.widget<Image>(find.descendant(
        of: find.byType(BeneficiaryAvatar),
        matching: find.byType(Image),
      ));
      expect(
        (portrait.image as AssetImage).assetName,
        'assets/images/default-avatar-middle-female.png',
      );
      final checkout =
          find.widgetWithText(FilledButton, 'Kết thúc ca làm việc (Check-out)');
      await tester.tap(checkout);
      await tester.pump();
      expect(actions.checkouts, 0);
      expect(find.text('Chưa thể kết thúc ca'), findsOneWidget);
      expect(tester.takeException(), isNull);
      AppToast.dismiss(tester.element(find.byType(ShiftActiveScreen)));
      if (width == 390 && textScale == 1) {
        await tester.tap(find.text('Ghi chú ca'));
        await tester.pumpAndSettle();
        expect(find.text('Ghi chú ca trực'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Bác đã ăn nhẹ.');
        await tester.tap(find.text('Xong'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ghi chú ca'));
        await tester.pumpAndSettle();
        expect(find.text('Bác đã ăn nhẹ.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
