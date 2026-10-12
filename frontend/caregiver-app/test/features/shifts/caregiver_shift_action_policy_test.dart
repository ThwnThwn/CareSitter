import 'package:flutter_test/flutter_test.dart';

import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

void main() {
  test('caregiver can receive only an open or pending offer', () {
    expect(_shift('open').canAccept, isTrue);
    expect(_shift('pending').canAccept, isTrue);
    expect(_shift('confirmed').canAccept, isFalse);
  });

  test('check-in is enabled only after caregiver starts travelling', () {
    expect(_shift('confirmed').canCheckIn, isFalse);
    expect(_shift('caregiver_en_route').canCheckIn, isTrue);
    expect(_shift('in_progress').canCheckIn, isFalse);
  });

  test('checklist actions are restricted to an in-progress shift', () {
    expect(_shift('caregiver_en_route').canWorkChecklist, isFalse);
    expect(_shift('in_progress').canWorkChecklist, isTrue);
    expect(_shift('checkout_pending_review').canWorkChecklist, isFalse);
  });

  test('photo-required task needs evidence before completion', () {
    const withoutEvidence = CareTaskModel(
      id: 'task-1',
      title: 'Đo huyết áp',
      requiresPhoto: true,
    );
    final withEvidence = withoutEvidence.copyWith(
      photoUrls: ['https://cdn.example/evidence.jpg'],
    );

    expect(withoutEvidence.canUploadEvidence, isTrue);
    expect(withoutEvidence.canComplete, isFalse);
    expect(withEvidence.canComplete, isTrue);
    expect(
        withEvidence.copyWith(status: 'COMPLETED').canUploadEvidence, isFalse);
  });

  test('checkout request is enabled only during an active shift', () {
    expect(_shift('in_progress').canRequestCheckout, isTrue);
    expect(_shift('checkout_pending_review').canRequestCheckout, isFalse);
    expect(_shift('completed').canRequestCheckout, isFalse);
  });
}

ShiftModel _shift(String status) => ShiftModel(
      id: 'booking-1',
      beneficiaryName: 'Nguyễn Văn A',
      caregiverName: 'Caregiver',
      caregiverAvatar: 'CG',
      serviceName: 'Chăm sóc tại nhà',
      date: '21/09/2026',
      time: '08:00 - 10:00',
      duration: '2 giờ',
      status: status,
      totalPrice: 200000,
      address: 'TP.HCM',
    );
