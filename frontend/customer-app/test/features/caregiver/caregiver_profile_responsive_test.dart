import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';
import 'package:caresitter_customer/features/caregiver/presentation/controllers/nearby_caregiver_controller.dart';
import 'package:caresitter_customer/features/caregiver/presentation/screens/caregiver_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('caregiver profile stacks actions on narrow enlarged layouts',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          caregiverDetailProvider('caregiver-responsive')
              .overrideWith((ref) async => _profileCaregiver),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.4),
            ),
            child: child!,
          ),
          home: const CaregiverProfileScreen(id: 'caregiver-responsive'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nguyễn Thị Chăm Sóc Viên Tận Tâm'), findsOneWidget);
    expect(find.text('Đặt lịch ngay'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _profileCaregiver = CaregiverModel(
  id: 'caregiver-responsive',
  userId: 'user-responsive',
  fullName: 'Nguyễn Thị Chăm Sóc Viên Tận Tâm',
  bio: 'Có nhiều năm kinh nghiệm hỗ trợ và đồng hành cùng người cao tuổi.',
  yearsOfExperience: 8,
  hourlyRateExpected: 185000,
  ratingAvg: 4.9,
  ratingCount: 128,
  availabilityStatus: 'ONLINE',
  skills: ['Chăm sóc người cao tuổi', 'Nhắc lịch uống thuốc'],
  serviceCity: 'Thành phố Hồ Chí Minh',
  serviceDistrict: 'Thành phố Thủ Đức',
);
