import 'package:caresitter_customer/features/nutrition/data/models/nutrition_meal_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_recommendation_trace_model.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_recommendation_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('meal-specific reasons are no longer listed in the menu header',
      (tester) async {
    final trace = NutritionRecommendationTraceModel.fromJson({
      'verifiedReasons': [
        {
          'recipeVersionId': 'one',
          'code': 'declared_allergy_filter',
          'detail': 'Tôm'
        },
        {
          'recipeVersionId': 'other',
          'code': 'declared_allergy_filter',
          'detail': 'Sữa'
        },
      ]
    });
    final meal = NutritionMealModel.fromJson(
        {'recipeVersionId': 'one', 'name': 'Cơm cá'});
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body:
                NutritionRecommendationContext(trace: trace, meals: [meal]))));
    expect(find.textContaining('Cơm cá: đã lọc dị ứng Tôm'), findsNothing);
    expect(find.text('Vì sao chọn thực đơn này?'), findsNothing);
    expect(find.textContaining('Sữa'), findsNothing);
  });

  testWidgets('local demo meals retain disclosure without graph grounding',
      (tester) async {
    final trace = NutritionRecommendationTraceModel.fromJson({
      'strategy': 'rule_baseline',
      'usedAi': false,
      'warnings': ['grounding_not_configured'],
    });
    final meal = NutritionMealModel.fromJson({
      'name': '[DEMO] Cháo trứng',
      'mealType': 'breakfast',
    });
    await tester.pumpWidget(MaterialApp(
      home: NutritionRecommendationContext(trace: trace, meals: [meal]),
    ));
    expect(find.text('DEMO'), findsOneWidget);
    expect(find.textContaining('Chưa kiểm duyệt lâm sàng'), findsOneWidget);
    expect(find.text('DEMO · GraphRAG'), findsNothing);
  });

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

    expect(find.text('AI CareSitter đề xuất'), findsOneWidget);
    expect(find.textContaining('AI xếp hạng'), findsOneWidget);
    expect(find.textContaining('Phù hợp giới hạn natri.'), findsNothing);
    expect(find.textContaining('Chưa có đủ căn cứ'), findsNothing);
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

    expect(find.text('CareSitter đề xuất'), findsOneWidget);
    expect(find.text('AI CareSitter đề xuất'), findsNothing);
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
    expect(find.text('CareSitter đề xuất'), findsOneWidget);
    expect(find.textContaining('Chưa kiểm duyệt lâm sàng.'), findsOneWidget);
  });

  testWidgets('reference release labels an explanation graph honestly',
      (tester) async {
    final trace = NutritionRecommendationTraceModel.fromJson({
      'strategy': 'graph_grounded_rule',
      'usedAi': false,
      'releaseStatus': 'reference',
      'retrievalStrategy': 'keyword',
      'graphRole': 'explanation',
      'groundingRevision': 'freeze-1',
      'evidence': [
        {'id': 'chunk-1', 'reference': 'Nguồn, trang 34'}
      ],
      'citations': [
        {
          'title': 'Tài liệu tham khảo',
          'chapter': 'Chương 1',
          'heading': 'Mục 2',
          'pages': '34',
          'graphPath': [
            {
              'nodeId': 'node-1',
              'heading': 'Chủ đề',
              'pages': [34]
            }
          ]
        }
      ]
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          NutritionRecommendationContext(trace: trace, meals: const []),
        ]),
      ),
    ));
    // Explanation-only graph must not be labelled GraphRAG.
    expect(find.text('Tham khảo · GraphRAG'), findsNothing);
    expect(
        find.text('Tham khảo · Trích dẫn sách + đồ thị nguồn'), findsOneWidget);
    expect(find.textContaining('chưa được chuyên gia dinh dưỡng kiểm duyệt'),
        findsOneWidget);
    expect(find.textContaining('Graph chỉ giải thích'), findsOneWidget);
    expect(find.text('DEMO'), findsNothing);
    await tester.tap(find.text('Tài liệu tham khảo'));
    await tester.pumpAndSettle();
    expect(find.text('Tài liệu tham khảo'), findsWidgets);
    expect(find.textContaining('Chủ đề · trang 34'), findsOneWidget);
  });

  testWidgets('graph retrieval label requires a released graph strategy',
      (tester) async {
    final trace = NutritionRecommendationTraceModel.fromJson({
      'strategy': 'graph_grounded_rule',
      'usedAi': false,
      'releaseStatus': 'released',
      'retrievalStrategy': 'graph',
      'graphRole': 'retrieval',
    });
    await tester.pumpWidget(MaterialApp(
      home: NutritionRecommendationContext(trace: trace, meals: const []),
    ));
    expect(find.text('Graph đã tham gia tra cứu nguồn.'), findsOneWidget);
    expect(find.text('Tham khảo · GraphRAG'), findsOneWidget);
    expect(find.text('DEMO'), findsNothing);
  });

  testWidgets('unknown release and graph role fail closed', (tester) async {
    final trace = NutritionRecommendationTraceModel.fromJson({
      'releaseStatus': 'pending',
      'graphRole': 'retrieval',
      'retrievalStrategy': 'graph',
    });
    await tester.pumpWidget(MaterialApp(
      home: NutritionRecommendationContext(trace: trace, meals: const []),
    ));
    expect(find.text('DEMO'), findsOneWidget);
    expect(find.textContaining('Graph đã tham gia'), findsNothing);
  });

  testWidgets('ungrounded recommendation states there are no citations',
      (tester) async {
    final trace = NutritionRecommendationTraceModel.fromJson({
      'releaseStatus': 'ungrounded',
      'strategy': 'rule_baseline',
      'usedAi': false,
      'evidence': [
        {'id': 'untrusted', 'reference': 'Should remain hidden'}
      ],
      'groundingRevision': 'untrusted',
    });
    await tester.pumpWidget(MaterialApp(
      home: NutritionRecommendationContext(trace: trace, meals: const []),
    ));
    expect(find.text('Gợi ý theo quy tắc, chưa có trích dẫn'), findsOneWidget);
    expect(find.textContaining('Should remain hidden'), findsNothing);
    expect(find.text('DEMO'), findsNothing);
  });
}
