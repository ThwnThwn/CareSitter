import 'package:caresitter_customer/features/nutrition/data/models/health_profile_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_resource_model.dart';
import 'package:caresitter_customer/features/nutrition/presentation/models/nutrition_flow_model.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_allergy_tag_field.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_profile_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('missing declarations show toast and mark fields',
      (tester) async {
    final health = HealthProfileModel.fromJson({'revision': 1});
    var assessed = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: NutritionProfileEditor(
      beneficiaryId: 'test',
      beneficiaryName: 'Test',
      plannedDate: DateTime(2026),
      session: 1,
      health: health,
      flow: NutritionFlow(health: health, canAssess: true),
      dirty: false,
      onDirtyChanged: (_) {},
      onSave: (_) {},
      onAssess: () => assessed = true,
    ))));
    final button = find.text('Lưu và kiểm tra thông tin');
    await tester.scrollUntilVisible(button, 400,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng bổ sung thông tin'), findsOneWidget);
    expect(find.text('Xác nhận dị ứng thực phẩm'), findsWidgets);
    await tester.scrollUntilVisible(
        find.text('Vui lòng xác nhận mục này').first, -400,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Vui lòng xác nhận mục này'), findsWidgets);
    expect(assessed, isFalse);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('unrecognized allergy highlights and focuses the allergy input',
      (tester) async {
    final health = HealthProfileModel.fromJson({
      'revision': 2,
      'foodAllergyStatus': 'reported_present',
      'allergies': ['Tôm', 'thịt bò'],
      'healthHistory': {
        'nutrition': {'conditionsStatus': 'reported_none'}
      },
    });
    final resource = NutritionResourceModel.fromJson({
      'status': 'needs_information',
      'data': {
        'decision': {
          'state': 'needs_information',
          'missingFields': ['allergies/1']
        }
      }
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NutritionProfileEditor(
          beneficiaryId: 'test',
          beneficiaryName: 'Test',
          plannedDate: DateTime(2026),
          session: 1,
          health: health,
          flow: NutritionFlow(
              health: health, resource: resource, canAssess: true),
          dirty: false,
          onDirtyChanged: (_) {},
          onSave: (_) {},
          onAssess: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final tagField = tester.widget<NutritionAllergyTagField>(
        find.byType(NutritionAllergyTagField));
    expect(tagField.errorText, contains('chưa được nhận diện'));
    final input = tester.widget<TextField>(
        find.byKey(const ValueKey('nutrition-allergies-input')));
    expect(input.focusNode?.hasFocus, isTrue);
    final decoration = tester
        .widget<AnimatedContainer>(
            find.byKey(const ValueKey('nutrition-allergies-field')))
        .decoration as BoxDecoration;
    expect(decoration.border!.top.color, isNot(Colors.transparent));
  });
}
