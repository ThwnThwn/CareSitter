import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_recommendation_trace_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/nutrition_disclaimer.dart';
import '../controllers/nutrition_disclaimer_controller.dart';

class NutritionDisclaimerBanner extends ConsumerStatefulWidget {
  const NutritionDisclaimerBanner({
    super.key,
    this.userId,
    this.trace,
    this.defaultDisclaimer,
    this.defaultVersion,
  });

  final String? userId;
  final NutritionRecommendationTraceModel? trace;
  final String? defaultDisclaimer, defaultVersion;

  @override
  ConsumerState<NutritionDisclaimerBanner> createState() =>
      _NutritionDisclaimerBannerState();
}

class _NutritionDisclaimerBannerState
    extends ConsumerState<NutritionDisclaimerBanner> {
  ProviderSubscription<NutritionDisclaimerState>? _subscription;
  final _promptedKeys = <NutritionDisclaimerKey>{};
  bool _dialogOpen = false;

  NutritionDisclaimerKey get _identity => (
        userId: widget.userId,
        version: widget.trace?.disclaimerVersion ??
            widget.defaultVersion ??
            NutritionDisclaimer.referenceVersion,
      );
  String get _text =>
      widget.trace?.disclaimer ??
      widget.defaultDisclaimer ??
      NutritionDisclaimer.reference;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant NutritionDisclaimerBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKey = (
      userId: oldWidget.userId,
      version: oldWidget.trace?.disclaimerVersion ??
          oldWidget.defaultVersion ??
          NutritionDisclaimer.referenceVersion,
    );
    if (oldKey != _identity) _listen();
  }

  void _listen() {
    _subscription?.close();
    _subscription = ref.listenManual(
      nutritionDisclaimerControllerProvider(_identity),
      (_, next) {
        if (next == NutritionDisclaimerState.needsAck) _prompt(_identity);
      },
      fireImmediately: true,
    );
  }

  void _prompt(NutritionDisclaimerKey key) {
    if (_dialogOpen || _promptedKeys.contains(key)) return;
    // Scheduled by the state listener, never by build.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          key != _identity ||
          _dialogOpen ||
          _promptedKeys.contains(key) ||
          ref.read(nutritionDisclaimerControllerProvider(key)) !=
              NutritionDisclaimerState.needsAck) {
        return;
      }
      _promptedKeys.add(key);
      _dialogOpen = true;
      final text = _text;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Thông tin tham khảo'),
            content: SingleChildScrollView(child: Text(text)),
            actions: [
              TextButton(
                onPressed: () async {
                  if (!mounted) return;
                  if (key == _identity) await _acknowledge(key);
                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Tôi hiểu'),
              ),
            ],
          ),
        ),
      );
      if (!mounted) return;
      _dialogOpen = false;
      final current = _identity;
      if (ref.read(nutritionDisclaimerControllerProvider(current)) ==
          NutritionDisclaimerState.needsAck) {
        _prompt(current);
      }
    });
  }

  Future<void> _acknowledge(NutritionDisclaimerKey key) async {
    if (key != _identity) return;
    final result = await ref
        .read(nutritionDisclaimerControllerProvider(key).notifier)
        .acknowledge();
    if (!mounted || key != _identity) return;
    if (result == NutritionDisclaimerAckResult.savedInMemoryOnly) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
          content: Text('Chưa lưu được xác nhận; lần sau sẽ hỏi lại.')));
    }
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final key = _identity;
    final state = ref.watch(nutritionDisclaimerControllerProvider(key));
    final acknowledged = state == NutritionDisclaimerState.acknowledged;
    return Material(
      color: AppColors.warningLight,
      child: ExpansionTile(
        key: ValueKey((key, acknowledged)),
        initiallyExpanded: !acknowledged,
        leading: const Icon(Icons.info_outline, color: AppColors.warning),
        title: Text('Gợi ý chỉ mang tính tham khảo',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.compact, 0, AppSpacing.compact, AppSpacing.sm),
        children: [
          _DisclaimerContent(
            text: _text,
            acknowledged: acknowledged,
            onAcknowledge: state == NutritionDisclaimerState.needsAck
                ? () => _acknowledge(key)
                : null,
          ),
        ],
      ),
    );
  }
}

class _DisclaimerContent extends StatelessWidget {
  const _DisclaimerContent({
    required this.text,
    required this.acknowledged,
    required this.onAcknowledge,
  });

  final String text;
  final bool acknowledged;
  final VoidCallback? onAcknowledge;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: Theme.of(context).textTheme.bodySmall),
              Align(
                alignment: Alignment.centerRight,
                child: acknowledged
                    ? Text('Đã xác nhận',
                        style: Theme.of(context).textTheme.bodySmall)
                    : TextButton(
                        onPressed: onAcknowledge,
                        child: const Text('Tôi hiểu'),
                      ),
              ),
            ],
          ),
        ),
      );
}
