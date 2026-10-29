import 'package:caresitter_customer/features/nutrition/data/models/nutrition_meal_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_recommendation_trace_model.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_recommendation_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('grounded AI recommendation explains its bounded role and source',
      (tester) async {
    final meal = NutritionMealModel.fromJson({
      'recipeVersionId': 'recipe-1',
      'name': 'Cơm cá',
      'mealType': 'lunch',
    });
    final trace = NutritionRecommendationTraceModel.fromJson({
      'strategy': 'graph_grounded_ai_ranked',
      'usedAi': true,
      'groundingRevision': 'freeze-v1',
      'groundingStrategy': 'graph',
      'evidence': [
        {
          'id': 'chunk-1',
          'title': 'Chế độ ăn',
          'reference': 'Viện Dinh dưỡng, trang 34',
          'locator': 'pdf-page:35'
        }
      ],
      'explanations': [
        {
          'recipeVersionId': 'recipe-1',
          'summary': 'Phù hợp giới hạn natri.',
          'evidenceIds': ['chunk-1']
        }
      ]
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          NutritionRecommendationContext(trace: trace, meals: [meal]),
        ]),
      ),
    ));

    expect(find.text('AI gợi ý dựa trên tài liệu tham khảo'), findsOneWidget);
    expect(find.textContaining('AI chỉ xếp hạng'), findsOneWidget);
    expect(
        find.textContaining('Cơm cá: Phù hợp giới hạn natri.'), findsOneWidget);
    await tester.tap(find.text('1 nguồn dùng để đối chiếu'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Viện Dinh dưỡng, trang 34'), findsOneWidget);
  });

  testWidgets('non AI trace never labels the menu as AI generated',
      (tester) async {
    final trace = NutritionRecommendationTraceModel.fromJson({
      'strategy': 'rule_baseline',
      'usedAi': false,
      'evidence': <Object>[],
      'explanations': <Object>[],
    });

    await tester.pumpWidget(MaterialApp(
      home: NutritionRecommendationContext(trace: trace, meals: const []),
    ));

    expect(find.text('Gợi ý theo bộ quy tắc an toàn'), findsOneWidget);
    expect(find.textContaining('AI gợi ý'), findsNothing);
  });

  for (final useAi in [false, true]) {
    testWidgets(
        'graph demo label survives AI=$useAi at narrow large-text width',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final trace = NutritionRecommendationTraceModel.fromJson({
        'strategy': useAi ? 'graph_grounded_ai_ranked' : 'graph_grounded_rule',
        'usedAi': useAi,
        'groundingStrategy': 'owner_authorized_graph_demo',
        'groundingRevision': 'freeze-demo',
        'warnings': ['academic_demo_owner_authorized'],
        'evidence': [
          {'id': 'chunk-1', 'reference': 'Viện Dinh dưỡng, trang 34'}
        ],
      });
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: ListView(children: [
              NutritionRecommendationContext(trace: trace, meals: const []),
            ]),
          ),
        ),
      ));

      expect(find.text('DEMO · GraphRAG'), findsOneWidget);
      expect(find.textContaining('Chưa kiểm duyệt lâm sàng.'), findsOneWidget);
      expect(find.textContaining('tài liệu đã duyệt'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'invalid demo graph shows demo fallback without claiming traversal',
      (tester) async {
    final trace = NutritionRecommendationTraceModel.fromJson({
      'strategy': 'rule_baseline',
      'usedAi': false,
      'groundingStrategy': 'owner_authorized_graph_demo',
      'warnings': [
        'academic_demo_owner_authorized',
        'grounding_graph_demo_authorization_invalid'
      ],
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NutritionRecommendationContext(trace: trace, meals: const []),
      ),
    ));

    expect(find.text('DEMO'), findsOneWidget);
    expect(find.text('DEMO · GraphRAG'), findsNothing);
    expect(find.text('Gợi ý theo bộ quy tắc an toàn'), findsOneWidget);
    expect(find.textContaining('Chưa kiểm duyệt lâm sàng.'), findsOneWidget);
  });
}
