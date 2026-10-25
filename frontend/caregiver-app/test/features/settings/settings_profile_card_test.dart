import 'package:caregiver_app/features/profile/data/models/caregiver_profile_model.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/settings_profile_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows caregiver work summary and opens the profile editor',
      (tester) async {
    var editRequests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsProfileCard(
            profile: const CaregiverProfileModel(
              id: 'caregiver-1',
              userId: 'user-1',
              fullName: 'Nguyễn Thị Bích Ngọc',
              serviceDistrict: 'Quận 3',
              serviceCity: 'Hồ Chí Minh',
              gender: 'FEMALE',
            ),
            completedShifts: 12,
            monthTotal: 3600000,
            onEditProfile: () => editRequests++,
          ),
        ),
      ),
    );

    expect(find.text('Nguyễn Thị Bích Ngọc'), findsOneWidget);
    expect(find.text('Quận 3, Hồ Chí Minh'), findsOneWidget);
    expect(find.text('12 ca'), findsOneWidget);
    expect(find.text('3.600.000đ'), findsOneWidget);

    await tester.tap(find.text('Chỉnh sửa hồ sơ'));
    expect(editRequests, 1);
  });
}
