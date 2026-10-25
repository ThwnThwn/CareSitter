import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_checklist_item_model.dart';
import 'package:caresitter_customer/features/catalog/presentation/widgets/service_checklist_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders checklist data supplied by the service contract',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: ServiceChecklistSection(
              items: [
                ServiceChecklistItemModel(
                  id: 'task-1',
                  name: 'Hỗ trợ bữa ăn',
                  description: 'Chuẩn bị theo hướng dẫn của gia đình.',
                  isRequired: true,
                  requiresPhoto: false,
                  sortOrder: 1,
                ),
              ],
              loading: false,
              onRetry: _noop,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Công việc có trong gói'), findsOneWidget);
    expect(find.text('Hỗ trợ bữa ăn'), findsOneWidget);
    expect(find.text('Bắt buộc'), findsOneWidget);
  });

  testWidgets('shows a retry action when checklist loading fails',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ServiceChecklistSection(
            items: const [],
            loading: false,
            error: 'network',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Thử lại'));
    expect(retried, isTrue);
  });
}

void _noop() {}
