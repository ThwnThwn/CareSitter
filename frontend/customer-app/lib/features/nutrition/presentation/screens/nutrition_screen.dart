import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/widgets/app_toast.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';

import '../controllers/nutrition_controller.dart';
import '../controllers/nutrition_entry_controller.dart';
import 'nutrition_screen_actions.dart';
import 'nutrition_screen_page.dart';
import 'nutrition_screen_page_actions.dart';
import 'nutrition_screen_page_state.dart';

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({
    super.key,
    required this.beneficiaryId,
    this.beneficiaryName,
    this.onChangeBeneficiary,
  });

  final String beneficiaryId;
  final String? beneficiaryName;
  final VoidCallback? onChangeBeneficiary;
  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen>
    with WidgetsBindingObserver {
  bool _dirty = false;
  bool _historyLoading = false;
  bool _editingProfile = false;
  VoidCallback? _closeSheet;

  bool _isCurrent(String beneficiary, Object session) =>
      mounted &&
      beneficiary == widget.beneficiaryId &&
      ref.read(nutritionSessionProvider) == session;

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
      _editingProfile = false;
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
  Widget build(BuildContext context) {
    _listenForStateChanges();
    final flow = ref.watch(nutritionFlowProvider(widget.beneficiaryId));
    final session = ref.watch(nutritionSessionProvider);
    final controller =
        ref.read(nutritionControllerProvider(widget.beneficiaryId).notifier);
    return _buildScreen(flow, session, controller);
  }

  void _listenForStateChanges() {
    ref.listen(nutritionSessionProvider, (_, __) {
      _closeSheet?.call();
      setState(() {
        _dirty = false;
      });
    });
    ref.listen(
        nutritionFlowProvider(widget.beneficiaryId)
            .select((s) => s.health?.revision), (old, next) {
      if (next != null && next != old) setState(() => _dirty = false);
    });
    ref.listen(
        nutritionFlowProvider(widget.beneficiaryId)
            .select((flow) => flow.resource?.status), (old, next) {
      if (next == 'saved' && old != 'saved') {
        final controller = ref
            .read(nutritionControllerProvider(widget.beneficiaryId).notifier);
        controller.adoptResourceDate();
        setState(() {
          _editingProfile = false;
        });
      } else if (next == 'suggested' && old != 'suggested') {
        setState(() => _editingProfile = false);
        AppToast.success(context, 'Đã tạo gợi ý thực đơn');
      }
    });
  }

  Widget _buildScreen(
    NutritionFlow flow,
    int session,
    NutritionFlowController controller,
  ) {
    final selectedDate =
        flow.selectedDate ?? DateUtils.dateOnly(DateTime.now());
    return NutritionScreenPage(
      userId: ref.watch(authStateProvider.select((s) => s.valueOrNull?.userId)),
      disclaimer:
          ref.watch(nutritionCapabilitiesProvider).valueOrNull?.disclaimer,
      disclaimerVersion: ref
          .watch(nutritionCapabilitiesProvider)
          .valueOrNull
          ?.disclaimerVersion,
      controller: controller,
      state: NutritionScreenPageState.fromFlow(
        beneficiaryId: widget.beneficiaryId,
        beneficiaryName: widget.beneficiaryName,
        session: session,
        flow: flow,
        selectedDate: selectedDate,
        dirty: _dirty,
        editingProfile: _editingProfile,
        historyLoading: _historyLoading,
        canChangeBeneficiary: widget.onChangeBeneficiary != null,
      ),
      actions: _pageActions(flow, controller, selectedDate),
    );
  }

  NutritionScreenPageActions _pageActions(
    NutritionFlow flow,
    NutritionFlowController controller,
    DateTime selectedDate,
  ) =>
      NutritionScreenPageActions(
        onReturnToMenu: () => setState(() => _editingProfile = false),
        onReturnToBeneficiaries: widget.onChangeBeneficiary ?? () {},
        onEdit: () => setState(() => _editingProfile = true),
        onOpenHistory: () => _history(controller),
        onChangeBeneficiary: widget.onChangeBeneficiary ?? () {},
        onReload: controller.load,
        onDirtyChanged: (value) => setState(() => _dirty = value),
        onSave: (changes) async {
          final beneficiary = widget.beneficiaryId;
          final session = ref.read(nutritionSessionProvider);
          final previousRevision = controller.revision;
          controller.selectDate(selectedDate);
          await controller.saveHealthAndAssess(changes,
              plannedDate: changes.isEmpty ? selectedDate : null);
          if (!mounted ||
              beneficiary != widget.beneficiaryId ||
              ref.read(nutritionSessionProvider) != session) {
            return;
          }
          if (controller.revision > previousRevision) {
            AppToast.success(
                context,
                controller.view.resource?.status == 'suggested'
                    ? 'Cập nhật thành công · Đã tạo gợi ý thực đơn'
                    : 'Cập nhật thông tin thành công');
          }
        },
        onAssess: () {
          controller.selectDate(selectedDate);
          controller.assess();
        },
        onReplace: (type) => _replace(controller, type),
        onDateSelected: flow.loading || flow.dateLoading
            ? null
            : (date) => _openPlanForDate(controller, date),
        onRetryDate: flow.loading || flow.dateLoading
            ? null
            : () => _openPlanForDate(controller, selectedDate),
        onCreatePlan: () => _createPlan(controller, selectedDate),
        onCreateWeek: () => _createWeek(controller, selectedDate),
        onConfirm: () =>
            _createWeek(controller, selectedDate, confirmFirst: true),
      );

  Future<void> _createWeek(
      NutritionFlowController controller, DateTime selectedDate,
      {bool confirmFirst = false}) async {
    final beneficiary = widget.beneficiaryId;
    final session = ref.read(nutritionSessionProvider);
    final days = await NutritionScreenActions.choosePlanDays(
      context: context,
      startDate: selectedDate,
      beneficiaryName: widget.beneficiaryName,
      onCloseSheetChanged: (close) => _closeSheet = close,
    );
    if (!mounted || days == null || !_isCurrent(beneficiary, session)) {
      return;
    }
    await NutritionScreenActions.createWeek(
      context: context,
      controller: controller,
      selectedDate: selectedDate,
      days: days,
      confirmFirst: confirmFirst,
      isCurrent: () => _isCurrent(beneficiary, session),
      onNeedsProfile: () => setState(() => _editingProfile = true),
    );
  }

  Future<void> _createPlan(
    NutritionFlowController controller,
    DateTime selectedDate,
  ) async {
    final beneficiary = widget.beneficiaryId;
    final session = ref.read(nutritionSessionProvider);
    final created =
        await controller.recommendForDateUsingConfirmedHealth(selectedDate);
    if (!_isCurrent(beneficiary, session)) {
      return;
    }
    if (!created) setState(() => _editingProfile = true);
  }

  Future<void> _replace(NutritionFlowController c, String mealType) async {
    final beneficiary = widget.beneficiaryId;
    final session = ref.read(nutritionSessionProvider);
    await NutritionScreenActions.replaceMeal(
      context: context,
      controller: c,
      mealType: mealType,
      isCurrent: () => _isCurrent(beneficiary, session),
      onCloseSheetChanged: (close) => _closeSheet = close,
    );
  }

  Future<void> _history(NutritionFlowController c) async {
    if (_historyLoading) return;
    setState(() => _historyLoading = true);
    final beneficiary = widget.beneficiaryId;
    final session = ref.read(nutritionSessionProvider);
    try {
      final opened = await NutritionScreenActions.openHistory(
        context: context,
        controller: c,
        isCurrent: () => _isCurrent(beneficiary, session),
        onCloseSheetChanged: (close) => _closeSheet = close,
      );
      if (opened && mounted) setState(() => _editingProfile = false);
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  Future<void> _openPlanForDate(
    NutritionFlowController controller,
    DateTime date,
  ) async {
    final beneficiary = widget.beneficiaryId;
    final session = ref.read(nutritionSessionProvider);
    final opened = await controller.openPlanForDate(date);
    if (opened && _isCurrent(beneficiary, session)) {
      setState(() => _editingProfile = false);
    }
  }
}
