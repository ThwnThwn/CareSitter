import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shared widgets grow instead of overflowing at large text scale',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.6),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const GradientHeader(
                  title: 'Thông tin chăm sóc của người thân trong gia đình',
                  subtitle: 'Nội dung này có thể hiển thị trên nhiều dòng.',
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Địa chỉ chăm sóc',
                    value: '123 Đường có tên rất dài, Thành phố Hồ Chí Minh',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppButton(
                    label: 'Xác nhận và tiếp tục đặt lịch chăm sóc',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
