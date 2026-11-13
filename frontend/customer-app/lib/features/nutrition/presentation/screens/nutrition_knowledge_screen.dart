import 'package:caresitter_customer/core/error/app_exception.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/nutrition_knowledge_controller.dart';
import '../widgets/nutrition_knowledge_results.dart';

class NutritionKnowledgeScreen extends ConsumerStatefulWidget {
  const NutritionKnowledgeScreen({super.key});

  @override
  ConsumerState<NutritionKnowledgeScreen> createState() =>
      _NutritionKnowledgeScreenState();
}

class _NutritionKnowledgeScreenState
    extends ConsumerState<NutritionKnowledgeScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(nutritionKnowledgeControllerProvider);
    final search = result.valueOrNull;
    final canSearch = _query.text.trim().length >= 3 &&
        _query.text.trim().length <= 160 &&
        !result.isLoading;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.nutrition),
        title: const Text('Tra cứu tài liệu dinh dưỡng'),
      ),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text('Hỏi kiến thức dinh dưỡng',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Tra cứu thông tin dinh dưỡng và xem trang nguồn để đối chiếu. Nội dung không thay thế tư vấn của chuyên gia y tế.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _query,
              maxLength: 160,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (canSearch) _search();
              },
              decoration: const InputDecoration(
                labelText: 'Bạn muốn tìm hiểu điều gì?',
                hintText: 'Ví dụ: chất xơ trong khẩu phần',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: canSearch ? _search : null,
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Tra cứu'),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (result.isLoading)
              const LinearProgressIndicator(
                  semanticsLabel: 'Đang tra cứu tài liệu')
            else if (result.hasError)
              _SearchMessage(
                icon: Icons.cloud_off_outlined,
                text: result.error is AppApiException
                    ? (result.error as AppApiException).message
                    : 'Chưa tra cứu được tài liệu. Vui lòng thử lại.',
                onRetry: _search,
              )
            else if (search == null)
              const _SearchMessage(
                icon: Icons.auto_stories_outlined,
                text: 'Nhập chủ đề bạn quan tâm để xem mục và trang nguồn.',
              )
            else if (search.results.isEmpty && !search.localDemo)
              const _SearchMessage(
                icon: Icons.search_off_rounded,
                text: 'Chưa tìm thấy mục phù hợp. Hãy thử từ khóa khác.',
              )
            else
              NutritionKnowledgeResults(search: search),
          ],
        ),
      ),
    );
  }

  void _search() {
    FocusScope.of(context).unfocus();
    ref.read(nutritionKnowledgeControllerProvider.notifier).search(_query.text);
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 40),
            const SizedBox(height: AppSpacing.sm),
            Text(text, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ],
        ),
      );
}
