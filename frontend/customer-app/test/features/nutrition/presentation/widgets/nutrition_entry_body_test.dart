import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/nutrition/presentation/models/nutrition_profile_item.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_entry_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('filters Vietnamese profiles without requiring accents',
      (tester) async {
    await tester.pumpWidget(_app(
      profiles: [
        _profile(id: 'loan', name: 'Trần Thị Loan', relationship: 'Mẹ'),
        _profile(id: 'minh', name: 'Nguyễn Văn Minh', relationship: 'Bố'),
      ],
    ));

    await tester.enterText(
      find.byKey(const ValueKey('nutrition-beneficiary-search')),
      'tran thi loan',
    );
    await tester.pump();

    expect(find.text('Trần Thị Loan'), findsOneWidget);
    expect(find.text('Nguyễn Văn Minh'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('nutrition-beneficiary-search')),
      'me',
    );
    await tester.pump();
    expect(find.text('Trần Thị Loan'), findsOneWidget);
  });

  testWidgets('selects the tapped profile', (tester) async {
    String? selected;
    await tester.pumpWidget(_app(
      profiles: [_profile(id: 'loan', name: 'Trần Thị Loan')],
      onSelect: (id) => selected = id,
    ));

    await tester.tap(find.byKey(const ValueKey('nutrition-beneficiary-loan')));

    expect(selected, 'loan');
  });

  testWidgets('forwards create actions in populated and empty states',
      (tester) async {
    var createCount = 0;
    await tester.pumpWidget(_app(
      profiles: [_profile(id: 'loan', name: 'Trần Thị Loan')],
      onCreate: () => createCount++,
    ));
    await tester.tap(find.text('Thêm hồ sơ người thân mới'));

    await tester.pumpWidget(_app(
      profiles: const [],
      onCreate: () => createCount++,
    ));
    await tester.tap(find.text('Tạo hồ sơ đầu tiên'));

    expect(createCount, 2);
  });

  testWidgets('distinguishes loading, error and empty states', (tester) async {
    var retryCount = 0;
    await tester.pumpWidget(_app(profiles: const [], isLoading: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Chưa có hồ sơ để lập thực đơn'), findsNothing);

    await tester.pumpWidget(_app(
      profiles: const [],
      hasError: true,
      onRetry: () => retryCount++,
    ));
    expect(find.text('Chưa tải được hồ sơ'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    expect(retryCount, 1);

    await tester.pumpWidget(_app(profiles: const []));
    expect(find.text('Chưa có hồ sơ để lập thực đơn'), findsOneWidget);
  });

  testWidgets('supports a narrow viewport and large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(
      textScaler: const TextScaler.linear(2),
      profiles: [
        _profile(
          id: 'long',
          name: 'Người thân có tên rất dài để kiểm tra giao diện',
        ),
      ],
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required List<NutritionProfileItem> profiles,
  ValueChanged<String>? onSelect,
  VoidCallback? onCreate,
  VoidCallback? onRetry,
  bool isLoading = false,
  bool hasError = false,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: Scaffold(
      body: NutritionEntryBody(
        profiles: profiles,
        isLoading: isLoading,
        hasError: hasError,
        onCreateProfile: onCreate ?? () {},
        onSelect: onSelect ?? (_) {},
        onRetry: onRetry ?? () {},
      ),
    ),
  );
}

NutritionProfileItem _profile({
  required String id,
  required String name,
  String relationship = 'Mẹ',
}) {
  return NutritionProfileItem(
    id: id,
    name: name,
    relationshipLabel: relationship,
    ageLabel: '70 tuổi',
    avatarInitial: name.characters.first,
    supportingText: 'Thông tin đã được lưu.',
  );
}
