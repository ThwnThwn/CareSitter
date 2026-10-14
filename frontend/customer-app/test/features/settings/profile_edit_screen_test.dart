import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_edit_controller.dart';
import 'package:caresitter_customer/features/settings/presentation/screens/profile_edit_screen.dart';

class _Profile extends StateNotifier<UserProfile> implements ProfileStore {
  _Profile()
      : super(const UserProfile(
            name: 'Nguyễn Văn An',
            displayName: 'An',
            phone: '0901234567',
            email: 'an@example.com',
            dob: '1990-01-01',
            gender: 'MALE'));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
      'both save actions lock during a write and a failed save keeps the edited name',
      (tester) async {
    final response = Completer<bool>();
    var writes = 0;
    String? writtenName;
    await tester.pumpWidget(ProviderScope(overrides: [
      profileStoreProvider.overrideWith((ref) => _Profile()),
      profileEditControllerProvider.overrideWith((ref) => ProfileEditController(
            uploadAvatar: (_, __) async => true,
            updateProfile: (
                {required name,
                required displayName,
                required email,
                required dob,
                required gender}) {
              writes++;
              writtenName = name;
              return response.future;
            },
          )),
    ], child: const MaterialApp(home: ProfileEditScreen())));
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    final name = find.ancestor(
        of: find.byWidgetPredicate((widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Họ và tên *'),
        matching: find.byType(TextFormField));
    await tester.enterText(name, 'A');
    await tester.tap(find.widgetWithText(TextButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    await tester.enterText(name, 'Nguyễn Văn Bình');
    await tester.tap(find.widgetWithText(TextButton, 'Lưu'));
    await tester.pump();
    expect(writes, 1);
    expect(writtenName, 'Nguyễn Văn Bình');
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Lưu'))
            .onPressed,
        isNull);
    await tester.scrollUntilVisible(find.byType(ElevatedButton), 300,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull);
    response.complete(false);
    await tester.pumpAndSettle();
    await tester.ensureVisible(name);
    expect(
        tester.widget<TextFormField>(name).controller!.text, 'Nguyễn Văn Bình');
    expect(find.text('Cập nhật thất bại. Vui lòng thử lại.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
