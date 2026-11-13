import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_knowledge_model.dart';
import 'package:caresitter_customer/features/nutrition/data/repositories/nutrition_knowledge_repository.dart';
import 'package:caresitter_customer/features/nutrition/presentation/controllers/nutrition_knowledge_controller.dart';
import 'package:caresitter_customer/features/nutrition/presentation/models/nutrition_knowledge_presentation.dart';
import 'package:caresitter_customer/features/nutrition/presentation/screens/nutrition_knowledge_screen.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_knowledge_source_card.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_knowledge_results.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> fixture({bool local = true, bool invalid = false}) => {
      'query': 'chất xơ',
      'localDemo': local,
      'answerProvider': 'Gemini',
      'answerStatus': 'answered',
      'answerChunkIds': ['s1', 's2', 's3', 's4', 's5'],
      'answerBlocks': [
        {
          'text': 'Câu trả lời được tổng hợp từ tài liệu.',
          'chunkIds': invalid ? ['missing'] : ['s1', 's5']
        },
        {
          'text': 'Phần giải thích bổ sung có nguồn.',
          'chunkIds': ['s3']
        },
      ],
      'results': List.generate(
          5,
          (i) => {
                'chunkId': 's${i + 1}',
                'heading': 'Mục nguồn ${i + 1}',
                'pdfPage': 10 + i,
                'sourceTitle': 'Tài liệu thử nghiệm',
                'sourceRevisionId': 'r1',
                'excerpt': 'Nội dung liên quan của nguồn ${i + 1}.',
              }),
    };

void main() {
  test(
      'maps generated blocks and keeps all five citations in their published order',
      () {
    final search = NutritionKnowledgeSearchModel.fromJson(fixture());
    expect(search.answerSources.length, 5);
    expect(NutritionKnowledgePresentation(search).answerText,
        'Câu trả lời được tổng hợp từ tài liệu. [1][5]\n\nPhần giải thích bổ sung có nguồn. [3]');
  });

  test('does not display generated text without authorized source binding', () {
    for (final data in [fixture(local: false), fixture(invalid: true)]) {
      final search = NutritionKnowledgeSearchModel.fromJson(data);
      expect(search.groundedAnswerBlocks, isEmpty);
      expect(NutritionKnowledgePresentation(search).hasAnswer, isFalse);
      expect(NutritionKnowledgePresentation(search).answerText,
          isNot(contains('Câu trả lời được tổng hợp')));
    }
  });

  testWidgets('uncited AI suggestion is distinct from related passages',
      (tester) async {
    final data = fixture()
      ..addAll({
        'answerStatus': 'ai_suggestion',
        'answerChunkIds': <String>[],
        'answerBlocks': [
          {'text': 'Gợi ý chung do Gemini đề xuất.', 'chunkIds': <String>[]}
        ],
      });
    final search = NutritionKnowledgeSearchModel.fromJson(data);
    expect(search.isAiSuggestion, isTrue);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: NutritionKnowledgeResults(search: search)))));
    expect(find.text('AI đề xuất · Gemini'), findsOneWidget);
    expect(find.text('Gợi ý chung do Gemini đề xuất.'), findsOneWidget);
    expect(find.text('Đoạn liên quan để đối chiếu'), findsOneWidget);
    expect(find.text('Nguồn đã dùng'), findsNothing);
    expect(find.text('[1] Mục nguồn 1'), findsNothing);
    for (final patch in [
      {'localDemo': false},
      {
        'answerChunkIds': ['s1']
      },
      {
        'answerBlocks': [
          {
            'text': 'Gợi ý chung do Gemini đề xuất.',
            'chunkIds': ['s1']
          }
        ]
      },
    ]) {
      expect(
          NutritionKnowledgeSearchModel.fromJson({...data, ...patch})
              .isAiSuggestion,
          isFalse);
    }
  });

  testWidgets(
      'app shows Gemini paragraphs, matching citations and content under each source',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      nutritionKnowledgeControllerProvider
          .overrideWith((_) => NutritionKnowledgeController(_Repository())),
    ], child: const MaterialApp(home: NutritionKnowledgeScreen())));
    await tester.enterText(find.byType(TextField), 'chất xơ');
    await tester.pump();
    await tester.tap(find.text('Tra cứu'));
    await tester.pumpAndSettle();
    expect(find.text('Câu trả lời từ tài liệu · Gemini'), findsOneWidget);
    expect(
        find.text(
            'Câu trả lời được tổng hợp từ tài liệu. [1][5]\n\nPhần giải thích bổ sung có nguồn. [3]'),
        findsOneWidget);
    expect(find.text('[5] Mục nguồn 5'), findsOneWidget);
    expect(find.text('Nội dung liên quan'), findsNWidgets(5));
    expect(find.text('Nội dung liên quan của nguồn 1.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'long source excerpt can expand and collapse at a narrow width with large text',
      (tester) async {
    tester.view.resetPhysicalSize();
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final excerpt = List.filled(12, 'Đây là đoạn nguồn thử nghiệm.').join(' ');
    final hit = NutritionKnowledgeHitModel.fromJson({
      ...Map<String, dynamic>.from((fixture()['results'] as List).first),
      'excerpt': excerpt
    });
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: Scaffold(
                body: SingleChildScrollView(
                    child: NutritionKnowledgeSourceCard(
                        hit: hit, showExcerpt: true, citation: 1))))));
    await tester.ensureVisible(find.text('Xem đầy đủ đoạn trích'));
    await tester.tap(find.text('Xem đầy đủ đoạn trích'));
    await tester.pump();
    expect(
        find.byWidgetPredicate(
            (widget) => widget is SelectableText && widget.data == excerpt),
        findsOneWidget);
    await tester.ensureVisible(find.text('Thu gọn đoạn trích'));
    await tester.tap(find.text('Thu gọn đoạn trích'));
    await tester.pump();
    expect(find.text('Xem đầy đủ đoạn trích'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Repository implements NutritionKnowledgeRepository {
  @override
  DioClient get api => throw UnimplementedError();
  @override
  Future<NutritionKnowledgeSearchModel> search(
          String query, ApiCancellation cancellation) async =>
      NutritionKnowledgeSearchModel.fromJson(fixture());
}
