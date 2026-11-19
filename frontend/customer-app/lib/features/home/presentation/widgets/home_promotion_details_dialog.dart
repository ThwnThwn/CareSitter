import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/utils/date_formatter.dart';
import 'package:caresitter_customer/features/promotions/data/models/promotion_model.dart';
import 'package:flutter/material.dart';
import 'home_promotion_conditions.dart';

class HomePromotionDetailsDialog extends StatefulWidget {
  const HomePromotionDetailsDialog({
    super.key,
    required this.promotion,
    required this.illustrationAsset,
    required this.onCopyCode,
  });

  final PromotionModel promotion;
  final String illustrationAsset;
  final Future<bool> Function() onCopyCode;

  @override
  State<HomePromotionDetailsDialog> createState() =>
      _HomePromotionDetailsDialogState();
}

class _HomePromotionDetailsDialogState
    extends State<HomePromotionDetailsDialog> {
  bool? _copied;
  bool _copying = false;

  Future<void> _copyCode() async {
    setState(() => _copying = true);
    final copied = await widget.onCopyCode();
    if (!mounted) return;
    setState(() {
      _copied = copied;
      _copying = false;
    });
  }

  @override
  Widget build(BuildContext context) => Dialog(
        constraints: const BoxConstraints(maxWidth: 420),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PromotionDetailsArtwork(
                        illustrationAsset: widget.illustrationAsset),
                    _PromotionDetailsContent(promotion: widget.promotion),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.section,
                AppSpacing.compact,
                AppSpacing.section,
                AppSpacing.section,
              ),
              child: _PromotionCopyAction(
                copied: _copied,
                onPressed: _copying ? null : _copyCode,
              ),
            ),
          ],
        ),
      );
}

class _PromotionCopyAction extends StatelessWidget {
  const _PromotionCopyAction({required this.copied, required this.onPressed});

  final bool? copied;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (copied == false) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                'Chưa sao chép được mã. Vui lòng thử lại.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                    ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Semantics(
            liveRegion: true,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, kMinInteractiveDimension),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.compact,
                ),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              onPressed: onPressed,
              icon: Icon(
                  copied == true ? Icons.check_rounded : Icons.copy_rounded,
                  size: AppFontSizes.s18),
              label: Text(copied == true ? 'Đã sao chép mã' : 'Sao chép mã'),
            ),
          ),
        ],
      );
}

class _PromotionDetailsArtwork extends StatelessWidget {
  const _PromotionDetailsArtwork({required this.illustrationAsset});

  final String illustrationAsset;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 2.35,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: AppColors.primaryContainer,
              child: Image.asset(
                illustrationAsset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                excludeFromSemantics: true,
              ),
            ),
            PositionedDirectional(
              top: AppSpacing.sm,
              end: AppSpacing.sm,
              child: IconButton.filled(
                tooltip: 'Đóng',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  minimumSize: const Size.square(kMinInteractiveDimension),
                ),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: AppFontSizes.s20),
              ),
            ),
          ],
        ),
      );
}

class _PromotionDetailsContent extends StatelessWidget {
  const _PromotionDetailsContent({required this.promotion});

  final PromotionModel promotion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.section,
        AppSpacing.md,
        AppSpacing.section,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            promotion.badgeText,
            style: theme.headlineMedium?.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            header: true,
            child: Text(
              promotion.title,
              style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            promotion.summary,
            style: theme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.compact),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  color: AppColors.textSecondary, size: AppFontSizes.s16),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Đến ${formatDate(promotion.endsAt)}',
                  style: theme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          HomePromotionConditions(promotion: promotion),
          _PromotionCodePanel(code: promotion.code),
        ],
      ),
    );
  }
}

class _PromotionCodePanel extends StatelessWidget {
  const _PromotionCodePanel({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.compact),
        child: Row(
          children: [
            const Icon(Icons.confirmation_number_outlined,
                color: AppColors.primary, size: AppFontSizes.s20),
            const SizedBox(width: AppSpacing.compact),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mã ưu đãi', style: theme.bodySmall),
                  const SizedBox(height: AppSpacing.micro),
                  Text(
                    code,
                    style: theme.titleMedium?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
