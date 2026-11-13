import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_knowledge_model.dart';
import 'package:caresitter_customer/features/nutrition/data/repositories/nutrition_knowledge_repository.dart';
import 'package:caresitter_customer/features/nutrition/presentation/controllers/nutrition_knowledge_controller.dart';
import 'package:caresitter_customer/features/nutrition/presentation/screens/nutrition_knowledge_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final openedDirectly in [true, false]) {
    testWidgets(
        'back returns to nutrition when opened directly=$openedDirectly',
        (tester) async {
      const priorPage = '/prior';
      final router = GoRouter(
        initialLocation:
            openedDirectly ? AppRoutes.nutritionKnowledge : priorPage,
        routes: [
          GoRoute(path: priorPage, builder: (_, __) => const Scaffold()),
          GoRoute(
            path: AppRoutes.nutrition,
            builder: (_, __) => const Scaffold(),
          ),
          GoRoute(
            path: AppRoutes.nutritionKnowledge,
            builder: (_, __) => const NutritionKnowledgeScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          nutritionKnowledgeControllerProvider.overrideWith(
            (_) => NutritionKnowledgeController(_SearchRepository()),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      if (!openedDirectly) {
        router.push<void>(AppRoutes.nutritionKnowledge);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path,
          openedDirectly ? AppRoutes.nutrition : priorPage);
    });
  }

  for (final unavailable in [true, false]) {
    testWidgets(
        'distinguishes model unavailable=$unavailable from missing evidence',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          nutritionKnowledgeControllerProvider.overrideWith(
            (_) => NutritionKnowledgeController(_SearchRepository(
                emptyStatus:
                    unavailable ? 'unavailable' : 'insufficient_evidence')),
          )
        ],
        child: const MaterialApp(home: NutritionKnowledgeScreen()),
      ));
      await tester.enterText(find.byType(TextField), 'chất xơ');
      await tester.pump();
      await tester.tap(find.text('Tra cứu'));
      await tester.pumpAndSettle();
      expect(
          find.textContaining(unavailable
              ? 'AI local chưa phản hồi'
              : 'Chưa tìm được đoạn tài liệu'),
          findsOneWidget);
      expect(find.text('Nguồn đã dùng'), findsNothing);
    });
  }
  test(
      'answer sources follow citation order, discard missing IDs and stay local',
      () {
    final response = {
      'query': 'chất xơ',
      'localDemo': true,
      'answerChunkIds': ['second', 'missing', 'first', 'second'],
      'results': [
        {'chunkId': 'first', 'excerpt': 'Đoạn một.'},
        {'chunkId': 'second', 'excerpt': 'Đoạn hai.'},
      ],
    };
    final local = NutritionKnowledgeSearchModel.fromJson(response);
    expect(local.answerSources.map((hit) => hit.chunkId), ['second', 'first']);
    final remote = NutritionKnowledgeSearchModel.fromJson(
        {...response, 'localDemo': false});
    expect(remote.answerSources, isEmpty);
  });

  testWidgets('combines excerpts in one answer and numbers the cited sources',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        nutritionKnowledgeControllerProvider.overrideWith(
          (_) =>
              NutritionKnowledgeController(_SearchRepository(multiple: true)),
        )
      ],
      child: const MaterialApp(home: NutritionKnowledgeScreen()),
    ));
    await tester.enterText(find.byType(TextField), 'chất xơ là gì');
    await tester.pump();
    await tester.tap(find.text('Tra cứu'));
    await tester.pumpAndSettle();
    expect(find.text('Đoạn trả lời thử nghiệm. [1]\n\nĐoạn thứ hai. [2]'),
        findsOneWidget);
    expect(find.text('[1] Mục đã dùng'), findsOneWidget);
    expect(find.text('[2] Mục thứ hai'), findsOneWidget);
    expect(find.text('Mục chưa dùng'), findsNothing);
  });
  testWidgets('shows one answer followed by its cited source', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        nutritionKnowledgeControllerProvider.overrideWith(
          (_) => NutritionKnowledgeController(_SearchRepository()),
        ),
      ],
      child: const MaterialApp(home: NutritionKnowledgeScreen()),
    ));

    await tester.enterText(find.byType(TextField), 'chất xơ là gì');
    await tester.pump();
    await tester.tap(find.text('Tra cứu'));
    await tester.pumpAndSettle();

    final answer = find.byWidgetPredicate((widget) =>
        widget is SelectableText && widget.data == 'Đoạn trả lời thử nghiệm.');
    final citedSource = find.text('Mục đã dùng');
    expect(answer, findsOneWidget);
    expect(find.text('Nguồn đã dùng'), findsOneWidget);
    expect(citedSource, findsOneWidget);
    expect(tester.getTopLeft(answer).dy,
        lessThan(tester.getTopLeft(citedSource).dy));
    expect(find.text('Mục chưa dùng'), findsNothing);
  });
}

class _SearchRepository implements NutritionKnowledgeRepository {
  _SearchRepository({this.multiple = false, this.emptyStatus});
  final bool multiple;
  final String? emptyStatus;
  @override
  DioClient get api => throw UnimplementedError();

  @override
  Future<NutritionKnowledgeSearchModel> search(
      String query, ApiCancellation cancellation) async {
    if (emptyStatus != null) {
      return NutritionKnowledgeSearchModel(
        query: query,
        localDemo: true,
        answerStatus: emptyStatus,
        results: const [],
      );
    }
    return NutritionKnowledgeSearchModel(
      query: query,
      localDemo: true,
      answerChunkId: 'used',
      answerChunkIds: multiple ? ['used', 'second'] : const [],
      results: [
        if (multiple)
          const NutritionKnowledgeHitModel(
            chunkId: 'second',
            heading: 'Mục thứ hai',
            pdfPage: 21,
            printedPage: '20',
            sourceTitle: 'Nguồn thử',
            sourceRevisionId: 'test',
            excerpt: 'Đoạn thứ hai.',
          ),
        const NutritionKnowledgeHitModel(
          chunkId: 'used',
          heading: 'Mục đã dùng',
          pdfPage: 20,
          printedPage: '19',
          sourceTitle: 'Nguồn thử',
          sourceRevisionId: 'test',
          excerpt: 'Đoạn trả lời thử nghiệm.',
        ),
        const NutritionKnowledgeHitModel(
          chunkId: 'unused',
          heading: 'Mục chưa dùng',
          pdfPage: 22,
          printedPage: '21',
          sourceTitle: 'Nguồn thử',
          sourceRevisionId: 'test',
        ),
      ],
    );
  }
}
