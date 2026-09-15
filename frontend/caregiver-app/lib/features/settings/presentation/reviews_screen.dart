import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../profile/presentation/providers/profile_provider.dart';
import '../data/caregiver_review_model.dart';

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
      final response = await ref
          .read(dioClientProvider)
          .get<Map<String, dynamic>>('/reviews/caregiver/${profile.id}');
      final items = response.data?['items'];
      if (!mounted) return;
      setState(() {
        _reviews = (items is List ? items : const [])
            .whereType<Map<String, dynamic>>()
            .map(CaregiverReviewModel.fromJson)
            .toList();
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
              ? _buildLoadError()
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // ── Rating Header Summary ──
                      _buildRatingSummaryCard(
                          avgRating, totalReviews, ratingCounts),
                      const SizedBox(height: 12),
                      // ── Reviews List ──
                      if (_reviews.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(24, 12, 24, 24),
                          child: Text(
                            'Chưa có đánh giá nào. Các nhận xét từ khách hàng sẽ hiển thị tại đây.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 14),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 8),
                          itemCount: _reviews.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final review = _reviews[index];
                            return _buildReviewItem(review);
                          },
                        ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildRatingSummaryCard(
      double avg, int total, List<int> ratingCounts) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          // Left: Big number
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  avg.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (idx) {
                    return Icon(
                      idx < avg.floor()
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: const Color(0xFFF1C40F),
                      size: 20,
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  '$total lượt đánh giá',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Middle divider
          Container(
            height: 80,
            width: 1,
            color: AppColors.border,
          ),
          // Right: Star Breakout
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Column(
                children: [
                  _buildProgressBar(5, ratingCounts[4], total),
                  const SizedBox(height: 4),
                  _buildProgressBar(4, ratingCounts[3], total),
                  const SizedBox(height: 4),
                  _buildProgressBar(3, ratingCounts[2], total),
                  const SizedBox(height: 4),
                  _buildProgressBar(2, ratingCounts[1], total),
                  const SizedBox(height: 4),
                  _buildProgressBar(1, ratingCounts[0], total),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(int stars, int count, int total) {
    return Row(
      children: [
        Text(
          '$stars',
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.star_rounded, color: Color(0xFFF1C40F), size: 13),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : count / total,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 36),
            const SizedBox(height: 12),
            const Text('Không tải được đánh giá',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _hasLoadError = false;
                });
                _loadReviews();
              },
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewItem(CaregiverReviewModel review) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  review.reviewerInitial,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.reviewerName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      review.shiftService,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: List.generate(5, (idx) {
                      return Icon(
                        idx < review.rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: const Color(0xFFF1C40F),
                        size: 14,
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    review.date,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.comment,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
