import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_dropdown_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses shared field and menu styling while selecting an item',
      (tester) async {
    String? selected = 'first';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AppDropdownField<String>(
              initialValue: selected,
              decoration: const InputDecoration(labelText: 'Danh mục'),
              items: const [
                DropdownMenuItem(value: 'first', child: Text('Mục thứ nhất')),
                DropdownMenuItem(value: 'second', child: Text('Mục thứ hai')),
              ],
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      ),
    );

    final input = tester.widget<InputDecorator>(find.byType(InputDecorator));
    final border = input.decoration.border! as OutlineInputBorder;
    final menu = tester.widget<MenuAnchor>(find.byType(MenuAnchor));

    expect(input.decoration.filled, isTrue);
    expect(input.decoration.fillColor, AppColors.surface);
    expect(border.borderRadius, BorderRadius.circular(AppRadius.xl));
    expect(menu.style!.alignment, AlignmentDirectional.bottomStart);
    expect(menu.useRootOverlay, isTrue);
    final triggerMaterial = tester.widget<Material>(
      find
          .ancestor(
            of: find.byType(InkWell),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(triggerMaterial.clipBehavior, Clip.antiAlias);
    expect(
      (triggerMaterial.shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(AppRadius.xl),
    );

    final fieldRect = tester.getRect(find.byType(InputDecorator));
    await tester.tap(find.text('Mục thứ nhất'));
    await tester.pumpAndSettle();
    final option = find.widgetWithText(MenuItemButton, 'Mục thứ hai');
    expect(option, findsOneWidget);
    expect(
        tester.getRect(option).top, greaterThanOrEqualTo(fieldRect.bottom - 1));
    final buttons =
        tester.widgetList<MenuItemButton>(find.byType(MenuItemButton));
    final firstShape =
        buttons.first.style?.shape?.resolve({}) as RoundedRectangleBorder;
    final lastShape =
        buttons.last.style?.shape?.resolve({}) as RoundedRectangleBorder;
    expect(firstShape.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(AppRadius.compact)));
    expect(
        lastShape.borderRadius,
        const BorderRadius.vertical(
            bottom: Radius.circular(AppRadius.compact)));

    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(selected, 'second');
    expect(find.byType(MenuItemButton), findsNothing);
  });

  testWidgets('does not open when disabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: AppDropdownField<String>(
            initialValue: 'first',
            enabled: false,
            items: const [
              DropdownMenuItem(value: 'first', child: Text('Mục thứ nhất')),
              DropdownMenuItem(value: 'second', child: Text('Mục thứ hai')),
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mục thứ nhất'));
    await tester.pumpAndSettle();

    expect(find.text('Mục thứ hai'), findsNothing);
  });

  testWidgets('validates and updates a value supplied by the parent',
      (tester) async {
    final formKey = GlobalKey<FormState>();
    String? current;
    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          rebuild = setState;
          return Form(
            key: formKey,
            child: AppDropdownField<String>(
              initialValue: current,
              decoration: const InputDecoration(labelText: 'Danh mục'),
              validator: (value) => value == null ? 'Bắt buộc chọn' : null,
              items: const [
                DropdownMenuItem(value: 'first', child: Text('Mục thứ nhất')),
                DropdownMenuItem(value: 'second', child: Text('Mục thứ hai')),
              ],
              onChanged: (value) => current = value,
            ),
          );
        }),
      ),
    ));

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Bắt buộc chọn'), findsOneWidget);

    rebuild(() => current = 'second');
    await tester.pumpAndSettle();
    expect(find.text('Mục thứ hai'), findsOneWidget);
    expect(formKey.currentState!.validate(), isTrue);
  });

  testWidgets('long labels stay within a 320 px field and opened menu',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const longLabel =
        'Một lựa chọn dinh dưỡng có tên rất dài để kiểm tra giao diện';
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: AppDropdownField<String>(
            initialValue: 'long',
            items: const [
              DropdownMenuItem(value: 'long', child: Text(longLabel)),
              DropdownMenuItem(value: 'short', child: Text('Ngắn')),
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(longLabel));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
