import 'package:caresitter_customer/core/utils/default_avatar.dart';
import 'package:caresitter_customer/features/beneficiary/data/models/beneficiary_model.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/wizard/steps/recipient_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'the default avatar fills the circle when the recipient is selected',
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

    Widget card({required bool selected}) => MaterialApp(
          home: Scaffold(
            body: RecipientCard(
              beneficiary: beneficiary,
              isSelected: selected,
              onTap: () {},
            ),
          ),
        );

    await tester.pumpWidget(card(selected: false));

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

    await tester.pumpWidget(card(selected: true));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(Image)), const Size.square(48));
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
