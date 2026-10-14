import '../../data/models/shift_model.dart';

ShiftBeneficiaryModel presentShiftBeneficiary(ShiftModel booking) {
  final name = booking.beneficiaryName.trim().isNotEmpty
      ? booking.beneficiaryName.trim()
      : 'Người thân';
  final initial = _getInitial(name);
  final age = booking.beneficiaryAge ?? 0;
  final relation = booking.beneficiaryRelationship?.isNotEmpty == true
      ? booking.beneficiaryRelationship!
      : 'Chưa cập nhật';
  final condition = booking.beneficiaryCondition?.isNotEmpty == true
      ? booking.beneficiaryCondition!
      : (booking.customerNote?.isNotEmpty == true
          ? booking.customerNote!
          : 'Chưa có thông tin');
  final notes = booking.beneficiaryNotes?.isNotEmpty == true
      ? booking.beneficiaryNotes!
      : (booking.customerNote?.isNotEmpty == true
          ? booking.customerNote!
          : 'Chưa có ghi chú');

  return ShiftBeneficiaryModel(
    id: booking.beneficiaryId ?? 'b_${booking.id}',
    name: name,
    age: age,
    relation: relation,
    avatarInitial: initial,
    condition: condition,
    careLevel: 'Chưa cập nhật',
    notes: notes,
  );
}

String _getInitial(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'N';
  return parts.first.substring(0, 1).toUpperCase();
}
