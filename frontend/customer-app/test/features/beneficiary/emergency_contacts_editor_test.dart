import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_contact_entry.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_emergency_contacts_editor.dart';

void main() {
  testWidgets(
      'contact removal preserves other drafts and two required contacts at narrow width',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final contacts = [BeneficiaryContactEntry(), BeneficiaryContactEntry()];
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
              body: SingleChildScrollView(
                  child: BeneficiaryEmergencyContactsEditor(contacts: contacts)))),
    )));
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    final add = find.text('Thêm liên hệ khẩn cấp');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    contacts.last.nameCtrl.text = 'Liên hệ được giữ';
    contacts.last.phoneCtrl.text = '0901234567';
    final remove = find.byTooltip('Xóa liên hệ khẩn cấp 1');
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(contacts, hasLength(2));
    expect(contacts.last.nameCtrl.text, 'Liên hệ được giữ');
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    for (final entry in contacts) {
      entry.dispose();
    }
  });
}
