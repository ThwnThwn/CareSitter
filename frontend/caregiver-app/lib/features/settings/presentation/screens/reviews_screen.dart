import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/router/navigation_helpers.dart';
import 'package:caregiver_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:caregiver_app/features/settings/data/models/caregiver_review_model.dart';
import 'package:caregiver_app/features/settings/presentation/controllers/settings_controller.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/review_rating_summary_card.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/review_item_card.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/review_load_error.dart';

class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  List<CaregiverReviewModel> _reviews = const [];
  bool _isLoading = true;
  bool _hasLoadError = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadReviews);
  }

  Future<void> _loadReviews() async {
    final profile = ref.read(profileProvider);
    if (profile.id.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final reviews = await ref
          .read(settingsControllerProvider)
          .getCaregiverReviews(profile.id);
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _isLoading = false;
        _hasLoadError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasLoadError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalReviews = _reviews.length;
    final avgRating = totalReviews == 0
        ? 0.0
        : _reviews.fold<double>(0, (sum, item) => sum + item.rating) /
            totalReviews;
    final ratingCounts = List<int>.filled(5, 0);
    for (final review in _reviews) {
      final index = review.rating.round().clamp(1, 5) - 1;
      ratingCounts[index]++;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Đánh giá & Nhận xét'),
        leading: const AppBackButton(fallbackRoute: '/settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasLoadError
              ? ReviewLoadError(
                  onRetry: () {
                    setState(() {
                      _isLoading = true;
                      _hasLoadError = false;
                    });
                    _loadReviews();
                  },
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // ── Rating Header Summary ──
                      ReviewRatingSummaryCard(
                        avgRating: avgRating,
                        totalReviews: totalReviews,
                        ratingCounts: ratingCounts,
                      ),
                      const SizedBox(height: AppSpacing.compact),

                      // ── Reviews List ──
                      if (_reviews.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(AppSpacing.lg,
                              AppSpacing.compact, AppSpacing.lg, AppSpacing.lg),
                          child: Text(
                            'Chưa có đánh giá nào. Các nhận xét từ khách hàng sẽ hiển thị tại đây.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: AppFontSizes.s14,
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          itemCount: _reviews.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.md),
                          itemBuilder: (context, index) {
                            return ReviewItemCard(review: _reviews[index]);
                          },
                        ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
    );
  }
}
