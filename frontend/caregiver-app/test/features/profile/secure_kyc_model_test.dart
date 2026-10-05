import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/features/profile/data/models/caregiver_profile_model.dart';

void main() {
  test('maps KYC media IDs and never exposes legacy public URLs', () {
    final model = CaregiverProfileModel.fromJson({
      'id': 'profile',
      'userId': 'owner',
      'cccdFrontMediaId': 'front',
      'cccdBackMediaId': 'back',
      'certificateMediaIds': ['certificate'],
      'cccdFrontUrl': 'https://public.invalid/front.png',
      'cccdBackUrl': 'https://public.invalid/back.png',
      'certificateUrls': ['https://public.invalid/cert.png'],
    });
    expect(model.cccdFrontMediaId, 'front');
    expect(model.cccdBackMediaId, 'back');
    expect(model.certificateMediaIds, ['certificate']);
    expect(model.cccdFrontUrl, isNull);
    expect(model.cccdBackUrl, isNull);
    expect(model.certificateUrls, isEmpty);
    expect(model.requiresSecureResubmission, isTrue);
  });
  test('secure profiles do not need legacy resubmission', () {
    final model = CaregiverProfileModel.fromJson({
      'id': 'profile',
      'userId': 'owner',
      'CccdFrontMediaId': 'front',
      'CccdBackMediaId': 'back',
      'CertificateMediaIds': [],
    });
    expect(model.requiresSecureResubmission, isFalse);
    expect(model.cccdFrontMediaId, 'front');
  });
}
