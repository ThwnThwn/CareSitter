import 'package:caresitter_customer/core/utils/default_avatar.dart';
import 'package:caresitter_customer/features/beneficiary/data/models/beneficiary_model.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/wizard/steps/recipient_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the gender and age default avatar when URL is missing',
      (tester) async {
    final beneficiary = BeneficiaryModel(
      id: 'relative-female',
      name: 'Đặng Lê Thùy Dương',
      dateOfBirth: DateTime(2003, 10, 1),
      gender: 'FEMALE',
      relation: 'Vợ/Chồng',
      avatarInitial: 'ĐLT',
      condition: '',
      careLevel: '',
      notes: '',
      address: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecipientCard(
            beneficiary: beneficiary,
            isSelected: false,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      defaultAvatarAsset(
        dateOfBirth: beneficiary.dateOfBirth,
        gender: beneficiary.gender,
        seed: beneficiary.id,
      ),
    );
    expect(find.text('ĐLT'), findsNothing);
  });
}
