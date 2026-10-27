import 'package:caresitter_customer/core/error/app_exception.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/nutrition_knowledge_controller.dart';
import '../../data/models/nutrition_knowledge_model.dart';

class NutritionKnowledgeScreen extends ConsumerStatefulWidget {
  const NutritionKnowledgeScreen({super.key});

  @override
  ConsumerState<NutritionKnowledgeScreen> createState() =>
      _NutritionKnowledgeScreenState();
}

class _NutritionKnowledgeScreenState extends ConsumerState<NutritionKnowledgeScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(nutritionKnowledgeControllerProvider);
    final canSearch = _query.text.trim().length >= 3 &&
        _query.text.trim().length <= 160 && !result.isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Tra cứu tài liệu dinh dưỡng')),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text('Tìm theo nội dung sách',
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
              onSubmitted: (_) { if (canSearch) _search(); },
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
              const LinearProgressIndicator(semanticsLabel: 'Đang tra cứu tài liệu')
            else if (result.hasError)
              _SearchMessage(
                icon: Icons.cloud_off_outlined,
                text: result.error is AppApiException
                    ? (result.error as AppApiException).message
                    : 'Chưa tra cứu được tài liệu. Vui lòng thử lại.',
                onRetry: _search,
              )
            else if (result.valueOrNull == null)
              const _SearchMessage(
                icon: Icons.auto_stories_outlined,
                text: 'Nhập chủ đề bạn quan tâm để xem đoạn liên quan và trang sách.',
              )
            else if (result.valueOrNull!.results.isEmpty)
              const _SearchMessage(
                icon: Icons.search_off_rounded,
                text: 'Chưa tìm thấy đoạn phù hợp. Hãy thử từ khóa khác.',
              )
            else ...[
              Text('Kết quả cho “${result.valueOrNull!.query}”',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              for (final hit in result.valueOrNull!.results) ...[
                _KnowledgeResult(hit: hit),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
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

class _KnowledgeResult extends StatelessWidget {
  const _KnowledgeResult({required this.hit});

  final NutritionKnowledgeHitModel hit;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hit.heading,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(height: AppSpacing.sm),
              SelectableText(hit.excerpt),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${hit.sourceTitle} · Trang PDF ${hit.pdfPage}'
                '${hit.printedPage == null ? '' : ' · Trang in ${hit.printedPage}'}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
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
