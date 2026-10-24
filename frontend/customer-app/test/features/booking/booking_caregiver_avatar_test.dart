import 'package:cached_network_image/cached_network_image.dart';
import 'package:caresitter_customer/core/widgets/caregiver_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the caregiver photo when the booking has an avatar URL',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CaregiverAvatar(
            avatarUrl: 'https://cdn.example/caregivers/bich-ngoc.jpg',
            initials: 'NN',
            radius: 24,
          ),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, 'https://cdn.example/caregivers/bich-ngoc.jpg');
  });

  testWidgets('falls back to a bundled default avatar when there is no URL',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CaregiverAvatar(
            initials: 'NN',
            radius: 24,
          ),
        ),
      ),
    );

    expect(find.byType(CachedNetworkImage), findsNothing);
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/images/default-avatar-middle-male.png',
    );
  });
}
