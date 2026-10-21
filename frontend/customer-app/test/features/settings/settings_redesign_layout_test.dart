import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/settings_beneficiaries_section.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/settings_flat_header.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/settings_profile_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile redesign fits a narrow screen with large text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SettingsFlatHeader(topPadding: 0),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SettingsProfileCard(
                        profile: UserProfile(
                          name: 'Văn Châu Trường Thuận',
                          displayName: 'Thuận',
                          phone: '0901234567',
                          email: 'thuan@example.com',
                          dob: '2000-01-01',
                          gender: 'MALE',
                        ),
                        bookingCount: 39,
                        totalSpent: 1216000,
                      ),
                      SizedBox(height: 18),
                      SettingsBeneficiariesSection(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byTooltip('Cài đặt hồ sơ'), findsOneWidget);
    expect(find.text('Tài khoản & dịch vụ CareSitter'), findsOneWidget);
    expect(find.text('Thông tin chăm sóc'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
