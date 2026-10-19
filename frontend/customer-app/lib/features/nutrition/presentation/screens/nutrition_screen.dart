import '../widgets/nutrition_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';
import '../controllers/nutrition_controller.dart';
import '../widgets/nutrition_health_form.dart';
import '../widgets/nutrition_personalization_requirement.dart';
import '../widgets/nutrition_result.dart';

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key, required this.beneficiaryId});
  final String beneficiaryId;
  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen>
    with WidgetsBindingObserver {
  bool _dirty = false;
  VoidCallback? _closeSheet;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant NutritionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.beneficiaryId != widget.beneficiaryId) {
      _closeSheet?.call();
      _dirty = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller =
        ref.read(nutritionControllerProvider(widget.beneficiaryId).notifier);
    if (state == AppLifecycleState.resumed) {
      controller.resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      controller.suspend();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _content(context);

  Widget _content(BuildContext context) {
    final flow = ref.watch(nutritionFlowProvider(widget.beneficiaryId));
    final session = ref.watch(nutritionSessionProvider);
    ref.listen(nutritionSessionProvider, (_, __) {
      _closeSheet?.call();
      setState(() => _dirty = false);
    });
    ref.listen(
        nutritionFlowProvider(widget.beneficiaryId)
            .select((s) => s.health?.revision), (old, next) {
      if (next != null && next != old) setState(() => _dirty = false);
    });
    final controller =
        ref.read(nutritionControllerProvider(widget.beneficiaryId).notifier);
    final profile = ref
        .watch(beneficiaryStoreProvider)
        .where((b) => b.id == widget.beneficiaryId)
        .firstOrNull;
    final health = flow.health;
    final readiness = flow.readiness;
    return Scaffold(
        appBar: AppBar(title: const Text('Gợi ý thực đơn')),
        body: health == null
            ? NutritionEmptyState(flow: flow, onReload: controller.load)
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.section),
                children: [
                    Text(
                        profile == null
                            ? 'Hồ sơ đang chọn'
                            : 'Thực đơn cho ${profile.name}',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                        'Kiểm tra thông tin sức khỏe trước khi xem gợi ý. Thông tin do bạn và gia đình cung cấp.'),
                    if (flow.error != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.compact),
                          child: Text(flow.error!,
                              style: const TextStyle(color: AppColors.error))),
                    if (flow.loading) const LinearProgressIndicator(),
                    const SizedBox(height: AppSpacing.lg),
                    NutritionHealthForm(
                        key: ValueKey(
                            'health-${widget.beneficiaryId}-${health.revision}-$session'),
                        health: health,
                        enabled: !flow.loading,
                        onDirtyChanged: (v) => setState(() => _dirty = v),
                        onSave: (changes) {
                          if (changes.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Chưa có thông tin thay đổi.')));
                            return;
                          }
                          controller.saveHealth(changes);
                        }),
                    const SizedBox(height: AppSpacing.compact),
                    NutritionPersonalizationRequirement(readiness: readiness),
                    const SizedBox(height: AppSpacing.compact),
                    if (_dirty)
                      const Text(
                          'Lưu phần thông tin đã cập nhật trước khi kiểm tra và xem gợi ý.'),
                    FilledButton(
                        onPressed:
                            flow.loading || _dirty ? null : controller.assess,
                        child: const Text('Kiểm tra thông tin')),
                    TextButton(
                        onPressed: flow.loading || _dirty
                            ? null
                            : () => _history(controller),
                        child: const Text('Xem thực đơn đã lưu')),
                    const SizedBox(height: AppSpacing.lg),
                    if (flow.resource != null && !_dirty)
                      NutritionResult(
                          flow: flow,
                          controller: controller,
                          onReplace: (type) => _replace(controller, type)),
                  ]));
  }

  Future<void> _replace(NutritionFlowController c, String mealType) async {
    final beneficiary = widget.beneficiaryId;
    final session = ref.read(nutritionSessionProvider);
    final options = await c.options(mealType);
    if (!mounted ||
        beneficiary != widget.beneficiaryId ||
        options == null ||
        ref.read(nutritionSessionProvider) != session) {
      return;
    }
    final chosen = await _sheet(
        builder: (context) => SafeArea(
            child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .6,
                child: options.isEmpty
                    ? const Center(
                        child: Padding(
                            padding: EdgeInsets.all(AppSpacing.lg),
                            child: Text(
                                'Chưa có món thay thế đáp ứng các yêu cầu của thực đơn.')))
                    : ListView(children: [
                        const ListTile(title: Text('Món thay thế phù hợp')),
                        for (final recipe in options)
                          ListTile(
                              title: Text(recipe.name),
                              subtitle:
                                  Text('Khẩu phần: ${recipe.servings} phần'),
                              onTap: () =>
                                  Navigator.pop(context, recipe.versionId))
                      ]))));
    if (mounted &&
        beneficiary == widget.beneficiaryId &&
        chosen != null &&
        ref.read(nutritionSessionProvider) == session) {
      await c.replace(chosen, mealType);
    }
  }

  Future<void> _history(NutritionFlowController c) async {
    final beneficiary = widget.beneficiaryId;
    final session = ref.read(nutritionSessionProvider);
    final plans = await c.plans();
    if (!mounted ||
        beneficiary != widget.beneficiaryId ||
        plans == null ||
        ref.read(nutritionSessionProvider) != session) {
      return;
    }
    final chosen = await _sheet(
        builder: (context) => SafeArea(
            child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .6,
                child: plans.isEmpty
                    ? const Center(child: Text('Chưa có thực đơn đã lưu.'))
                    : ListView(children: [
                        const ListTile(title: Text('Thực đơn đã lưu gần đây')),
                        for (final plan in plans)
                          ListTile(
                              title: Text('Ngày ${plan.plannedDate}'),
                              subtitle: Text(plan.status == 'stale'
                                  ? 'Cần kiểm tra lại thông tin'
                                  : 'Đã lưu'),
                              onTap: () => Navigator.pop(context, plan.id))
                      ]))));
    if (mounted &&
        beneficiary == widget.beneficiaryId &&
        chosen != null &&
        ref.read(nutritionSessionProvider) == session) {
      await c.openPlan(chosen);
    }
  }

  Future<String?> _sheet({required WidgetBuilder builder}) async {
    try {
      return await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          builder: (sheetContext) {
            _closeSheet = () {
              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
            };
            return builder(sheetContext);
          });
    } finally {
      _closeSheet = null;
    }
  }
}
