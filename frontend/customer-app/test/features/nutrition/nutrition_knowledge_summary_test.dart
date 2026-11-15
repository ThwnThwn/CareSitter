import 'package:caresitter_customer/features/nutrition/data/models/nutrition_knowledge_model.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_knowledge_source_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const summary = 'Mục này mô tả nguyên tắc dinh dưỡng trong dữ liệu kiểm thử.';
const excerpt = 'Đoạn liên quan trực tiếp đến câu hỏi trong dữ liệu kiểm thử.';

void main() {
  testWidgets(
      'shows section summary above the matching passage and keeps source pages',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final hit = NutritionKnowledgeHitModel.fromJson({
      'chunkId': 'section',
      'heading': 'Nguyên tắc chế độ dinh dưỡng',
      'pdfPage': 136,
      'printedPage': '135',
      'sourceTitle': 'Tài liệu thử',
      'sourceRevisionId': 'fixture',
      'summary': summary,
      'excerpt': excerpt,
    });
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: Scaffold(
                body: SingleChildScrollView(
                    child: NutritionKnowledgeSourceCard(
                        hit: hit, showExcerpt: true))))));
    expect(find.text('Tóm tắt mục'), findsOneWidget);
    expect(find.text(summary), findsOneWidget);
    expect(find.text('Đoạn khớp câu hỏi'), findsOneWidget);
    expect(tester.getTopLeft(find.text(summary)).dy,
        lessThan(tester.getTopLeft(find.text(excerpt)).dy));
    expect(find.textContaining('Trang PDF 136 · Trang in 135'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('metadata-only response never displays book summary or excerpt',
      (tester) async {
    const hit = NutritionKnowledgeHitModel(
        chunkId: 'section',
        heading: 'Mục nguồn',
        pdfPage: 1,
        printedPage: '1',
        sourceTitle: 'Nguồn thử',
        sourceRevisionId: 'fixture',
        summary: summary,
        excerpt: excerpt);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: NutritionKnowledgeSourceCard(hit: hit, showExcerpt: false))));
    expect(find.text('Tóm tắt mục'), findsNothing);
    expect(find.text(summary), findsNothing);
    expect(find.text(excerpt), findsNothing);
  });

  testWidgets('same summary and passage appear once', (tester) async {
    const hit = NutritionKnowledgeHitModel(
        chunkId: 'section',
        heading: 'Mục nguồn',
        pdfPage: 1,
        printedPage: '1',
        sourceTitle: 'Nguồn thử',
        sourceRevisionId: 'fixture',
        summary: summary,
        excerpt: summary);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: NutritionKnowledgeSourceCard(hit: hit, showExcerpt: true))));
    expect(find.text(summary), findsOneWidget);
    expect(find.text('Đoạn khớp câu hỏi'), findsNothing);
  });
}
