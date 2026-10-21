import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/utils/normalize_search_text.dart';
import 'package:flutter/material.dart';

import '../models/nutrition_profile_item.dart';
import 'nutrition_entry_state.dart';
import 'nutrition_profile_card.dart';

class NutritionEntryBody extends StatefulWidget {
  const NutritionEntryBody({
    super.key,
    required this.profiles,
    required this.onCreateProfile,
    required this.onSelect,
    required this.onRetry,
    this.isLoading = false,
    this.hasError = false,
  });

  final List<NutritionProfileItem> profiles;
  final VoidCallback onCreateProfile;
  final ValueChanged<String> onSelect;
  final VoidCallback onRetry;
  final bool isLoading;
  final bool hasError;

  @override
  State<NutritionEntryBody> createState() => _NutritionEntryBodyState();
}

class _NutritionEntryBodyState extends State<NutritionEntryBody> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profiles.isEmpty && widget.isLoading) {
      return const NutritionEntryState.loading();
    }
    if (widget.profiles.isEmpty && widget.hasError) {
      return NutritionEntryState.error(onAction: widget.onRetry);
    }
    if (widget.profiles.isEmpty) {
      return NutritionEntryState.empty(onAction: widget.onCreateProfile);
    }
    final query = normalizeSearchText(_query);
    final visible = widget.profiles.where((profile) {
      if (query.isEmpty) return true;
      return normalizeSearchText(profile.name).contains(query) ||
          normalizeSearchText(profile.relationshipLabel).contains(query);
    }).toList(growable: false);
    return _ProfilesList(
      profiles: visible,
      query: _query,
      searchController: _searchController,
      onQueryChanged: (value) => setState(() => _query = value),
      onClearQuery: () {
        _searchController.clear();
        setState(() => _query = '');
      },
      onCreateProfile: widget.onCreateProfile,
      onSelect: widget.onSelect,
    );
  }
}

class _ProfilesList extends StatelessWidget {
  const _ProfilesList({
    required this.profiles,
    required this.query,
    required this.searchController,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onCreateProfile,
    required this.onSelect,
  });

  final List<NutritionProfileItem> profiles;
  final String query;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final VoidCallback onCreateProfile;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            const _NutritionEntryHeader(),
            const SizedBox(height: AppSpacing.comfortable),
            TextField(
              key: const ValueKey('nutrition-beneficiary-search'),
              controller: searchController,
              textInputAction: TextInputAction.search,
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                labelText: 'Tìm người cần lập thực đơn',
                hintText: 'Nhập tên hoặc mối quan hệ',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Xóa nội dung tìm kiếm',
                        onPressed: onClearQuery,
                        icon: const Icon(Icons.close_rounded),
                      ),
                fillColor: AppColors.surface,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (profiles.isEmpty)
              _NoSearchResult(query: query)
            else
              for (final profile in profiles)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.compact),
                  child: NutritionProfileCard(
                    profile: profile,
                    onTap: () => onSelect(profile.id),
                  ),
                ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              onPressed: onCreateProfile,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Thêm hồ sơ người thân mới'),
            ),
            const SizedBox(height: AppSpacing.md),
            const _NutritionTip(),
          ],
        ),
      );
}

class _NutritionEntryHeader extends StatelessWidget {
  const _NutritionEntryHeader();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chọn người cần lập thực đơn',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Gợi ý được cá nhân hóa theo thông tin sức khỏe và nhu cầu ăn uống đã xác nhận của từng người.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSizes.s13,
              height: 1.5,
            ),
          ),
        ],
      );
}

class _NutritionTip extends StatelessWidget {
  const _NutritionTip();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary),
            SizedBox(width: AppSpacing.compact),
            Expanded(
              child: Text(
                'Cập nhật hồ sơ khi tình trạng sức khỏe hoặc nhu cầu ăn uống thay đổi để gợi ý phù hợp hơn.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFontSizes.s12,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );
}

class _NoSearchResult extends StatelessWidget {
  const _NoSearchResult({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          children: [
            const Icon(
              Icons.person_search_outlined,
              size: 44,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Không tìm thấy hồ sơ “${query.trim()}”',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      );
}
