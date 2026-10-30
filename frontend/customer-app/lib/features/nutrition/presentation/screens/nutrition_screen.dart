import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/nutrition_controller.dart';
import '../widgets/nutrition_plan_history_sheet.dart';
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
      }
    });
  }

  Widget _buildScreen(
    NutritionFlow flow,
    int session,
    NutritionFlowController controller,
  ) {
    final health = flow.health;
    final resourceDate = DateTime.tryParse(
      flow.resource?.result.plannedDate ?? '',
    );
    final selectedDate = flow.selectedDate ??
        (resourceDate == null
            ? DateUtils.dateOnly(DateTime.now())
            : DateUtils.dateOnly(resourceDate));
    final hasPlanForSelectedDate = flow.resource != null &&
        (resourceDate == null ||
            DateUtils.isSameDay(resourceDate, selectedDate));
    final dateError =
        flow.dateError ?? (!hasPlanForSelectedDate ? flow.error : null);
    final editing = !flow.restoringPlan && (_editingProfile || health == null);
    return NutritionScreenPage(
      controller: controller,
      state: _pageState(flow, session, selectedDate, hasPlanForSelectedDate,
          dateError, editing),
      actions: _pageActions(flow, controller, selectedDate),
    );
  }

  NutritionScreenPageState _pageState(
    NutritionFlow flow,
    int session,
    DateTime selectedDate,
    bool hasPlanForSelectedDate,
    String? dateError,
    bool editing,
  ) =>
      NutritionScreenPageState(
        beneficiaryId: widget.beneficiaryId,
        beneficiaryName: widget.beneficiaryName,
        session: session,
        flow: flow,
        health: flow.health,
        editing: editing,
        dirty: _dirty,
        selectedDate: selectedDate,
        hasPlanForSelectedDate: hasPlanForSelectedDate,
        isLoadingSelectedDate: flow.dateLoading,
        dateError: dateError,
        canReturnToMenu:
            _editingProfile && flow.health != null && !_dirty && !flow.loading,
        canReturnToBeneficiaries:
            widget.onChangeBeneficiary != null && !_dirty && !flow.loading,
        canEdit: flow.health != null && !_editingProfile && !flow.loading,
        canOpenHistory: flow.health != null &&
            !_dirty &&
            !flow.loading &&
            !_historyLoading &&
            !flow.dateLoading,
        canChangeBeneficiary:
            widget.onChangeBeneficiary != null && !_dirty && !flow.loading,
      );

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
        onSave: (changes) =>
            NutritionScreenActions.saveHealth(context, controller, changes),
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
      );

  Future<void> _createPlan(
    NutritionFlowController controller,
    DateTime selectedDate,
  ) async {
    final beneficiary = widget.beneficiaryId;
    final session = ref.read(nutritionSessionProvider);
    final created =
        await controller.recommendForDateUsingConfirmedHealth(selectedDate);
    if (!mounted ||
        beneficiary != widget.beneficiaryId ||
        ref.read(nutritionSessionProvider) != session) {
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
      isCurrent: () =>
          mounted &&
          beneficiary == widget.beneficiaryId &&
          ref.read(nutritionSessionProvider) == session,
      onCloseSheetChanged: (close) => _closeSheet = close,
    );
  }

  Future<void> _history(NutritionFlowController c) async {
    if (_historyLoading) return;
    setState(() => _historyLoading = true);
    final beneficiary = widget.beneficiaryId;
    final session = ref.read(nutritionSessionProvider);
    try {
      final plans = await c.plans();
      if (!mounted ||
          beneficiary != widget.beneficiaryId ||
          plans == null ||
          ref.read(nutritionSessionProvider) != session) {
        return;
      }
      final chosen = await NutritionScreenActions.showSheet<String>(
        context: context,
        onCloseSheetChanged: (close) => _closeSheet = close,
        builder: (_) => NutritionPlanHistorySheet(plans: plans),
      );
      if (mounted &&
          beneficiary == widget.beneficiaryId &&
          chosen != null &&
          ref.read(nutritionSessionProvider) == session) {
        await c.openPlan(chosen);
        if (!mounted ||
            beneficiary != widget.beneficiaryId ||
            ref.read(nutritionSessionProvider) != session) {
          return;
        }
        final openedResource = c.view.resource;
        final plannedDate = openedResource?.id == chosen
            ? DateTime.tryParse(openedResource!.result.plannedDate ?? '')
            : null;
        if (plannedDate != null) c.adoptResourceDate();
        setState(() {
          _editingProfile = false;
        });
      }
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
    if (opened &&
        mounted &&
        beneficiary == widget.beneficiaryId &&
        ref.read(nutritionSessionProvider) == session) {
      setState(() => _editingProfile = false);
    }
  }
}
