import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_toast.dart';
import 'package:caresitter_customer/features/promotions/data/models/promotion_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/home_featured_card_size.dart';
import 'home_promotion_details_dialog.dart';

class HomePromoCard extends StatelessWidget {
  const HomePromoCard({super.key, required this.promotion});

  final PromotionModel promotion;

  String get _illustrationAsset => promotion.firstPaidBookingOnly
      ? 'assets/images/promotion-welcome.webp'
      : 'assets/images/promotion-calm.webp';

  Future<bool> _copyCode() async {
    try {
      await Clipboard.setData(ClipboardData(text: promotion.code));
      return true;
    } on PlatformException {
      return false;
    }
  }

  Future<void> _copyFromCard(BuildContext context) async {
    final copied = await _copyCode();
    if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) return;
    if (copied) {
      AppToast.success(context, 'Đã sao chép mã ưu đãi.');
    } else {
      AppToast.error(context, 'Chưa sao chép được mã. Vui lòng thử lại.');
    }
  }

  Future<void> _showDetails(BuildContext context) {
    AppToast.dismiss(context);
    return showDialog<void>(
      context: context,
      builder: (_) => HomePromotionDetailsDialog(
        promotion: promotion,
        illustrationAsset: _illustrationAsset,
        onCopyCode: _copyCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size =
        homeFeaturedCardSize(MediaQuery.textScalerOf(context).scale(1));
    return SizedBox.fromSize(
      size: size,
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Semantics(
                label: promotion.title,
                hint: 'Xem chi tiết ưu đãi',
                button: true,
                child: InkWell(
                  onTap: () => _showDetails(context),
                  child: _HomePromoBanner(
                    illustrationAsset: _illustrationAsset,
                    badgeText: promotion.badgeText,
                  ),
                ),
              ),
            ),
            const Divider(height: AppSpacing.hairline),
            Tooltip(
              message: 'Sao chép mã ${promotion.code}',
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, kMinInteractiveDimension),
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                ),
                onPressed: () => _copyFromCard(context),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.copy_rounded, size: AppFontSizes.s16),
                label: Text(
                  promotion.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomePromoBanner extends StatelessWidget {
  const _HomePromoBanner({
    required this.illustrationAsset,
    required this.badgeText,
  });

  final String illustrationAsset;
  final String badgeText;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            illustrationAsset,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
          PositionedDirectional(
            start: AppSpacing.sm,
            end: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: Align(
              alignment: AlignmentDirectional.bottomStart,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.micro,
                  ),
                  child: Text(
                    badgeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}
