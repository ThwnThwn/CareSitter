import 'package:caregiver_app/features/shifts/presentation/widgets/shift_beneficiary_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('never guesses a gendered avatar when gender is unavailable',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShiftBeneficiaryAvatar(
            name: 'Văn Châu Trường Thuận',
            age: 23,
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
  });

  testWidgets('uses the middle-age female avatar for a female beneficiary',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShiftBeneficiaryAvatar(
            name: 'Trần Thị Loan',
            age: 49,
            gender: 'FEMALE',
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as AssetImage;
    expect(
      provider.assetName,
      'assets/images/default-avatar-middle-female.png',
    );
  });

  testWidgets('uses the middle-age male avatar for a male beneficiary',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShiftBeneficiaryAvatar(
            name: 'Nguyễn Văn Ba',
            age: 48,
            gender: 'MALE',
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as AssetImage;
    expect(
      provider.assetName,
      'assets/images/default-avatar-middle-male.png',
    );
  });

  testWidgets('uses the senior male avatar for an older male beneficiary',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShiftBeneficiaryAvatar(
            name: 'Ông Nguyễn Văn Ba',
            age: 78,
            gender: 'MALE',
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as AssetImage;
    expect(
      provider.assetName,
      'assets/images/default-avatar-senior-male.png',
    );
  });
}
