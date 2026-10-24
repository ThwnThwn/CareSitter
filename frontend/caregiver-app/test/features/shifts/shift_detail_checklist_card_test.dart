import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_detail_checklist_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _booking = ShiftModel(
  id: 'shift',
  beneficiaryName: 'An',
  caregiverName: 'Caregiver',
  caregiverAvatar: '',
  serviceName: 'Hỗ trợ thiết yếu',
  status: 'caregiver_en_route',
  totalPrice: 200000,
  address: 'TP. Hồ Chí Minh',
);

const _beneficiary = ShiftBeneficiaryModel(
  id: 'beneficiary',
  name: 'An',
  age: 70,
  relation: 'Mẹ',
  avatarInitial: 'A',
  condition: 'Chưa có thông tin',
  careLevel: 'Chưa cập nhật',
  notes: 'không có',
);

void main() {
  testWidgets('empty checklist does not repeat an empty-like note',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ShiftDetailChecklistCard(
          booking: _booking,
          beneficiary: _beneficiary,
        ),
      ),
    ));

    expect(find.text('Không có checklist công việc đặc biệt.'), findsOneWidget);
    expect(find.text('không có'), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });
}
