import 'package:caregiver_app/core/theme/app_spacing.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_action_feedback.dart';

enum ShiftTaskEditorMode { create, skip, incident }

class ShiftTaskEditor extends ConsumerStatefulWidget {
  const ShiftTaskEditor(
      {super.key, required this.bookingId, required this.mode, this.taskId});
  final String bookingId;
  final ShiftTaskEditorMode mode;
  final String? taskId;
  @override
  ConsumerState<ShiftTaskEditor> createState() => _ShiftTaskEditorState();
}

class _ShiftTaskEditorState extends ConsumerState<ShiftTaskEditor> {
  final _name = TextEditingController(), _description = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = ref.read(shiftActiveProvider(widget.bookingId).notifier);
    final result = await switch (widget.mode) {
      ShiftTaskEditorMode.create =>
        controller.createTask(_name.text, _description.text),
      ShiftTaskEditorMode.skip =>
        controller.skipTask(widget.taskId!, _description.text),
      ShiftTaskEditorMode.incident =>
        controller.reportIncident(_description.text),
    };
    if (!mounted) return;
    if (showShiftActionResult(context, result,
        success: widget.mode == ShiftTaskEditorMode.incident
            ? 'Đã gửi báo cáo khẩn cấp đến khách hàng và admin.'
            : null)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = switch (widget.mode) {
      ShiftTaskEditorMode.create => 'create',
      ShiftTaskEditorMode.skip => 'task:${widget.taskId}',
      ShiftTaskEditorMode.incident => 'incident'
    };
    final busy = ref.watch(shiftActiveProvider(widget.bookingId)
        .select((s) => s.busy.contains(key)));
    final title = switch (widget.mode) {
      ShiftTaskEditorMode.create => 'Thêm việc phát sinh',
      ShiftTaskEditorMode.skip => 'Lý do bỏ qua công việc',
      ShiftTaskEditorMode.incident => 'Báo cáo sự cố'
    };
    return SafeArea(
        child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.section,
                AppSpacing.lg, 24 + MediaQuery.viewInsetsOf(context).bottom),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  if (widget.mode == ShiftTaskEditorMode.create)
                    TextField(
                        controller: _name,
                        enabled: !busy,
                        maxLength: 255,
                        decoration: const InputDecoration(
                            labelText: 'Tên công việc *')),
                  TextField(
                      controller: _description,
                      enabled: !busy,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: InputDecoration(
                          labelText: widget.mode == ShiftTaskEditorMode.create
                              ? 'Ghi chú (tùy chọn)'
                              : title)),
                  const SizedBox(height: AppSpacing.compact),
                  FilledButton(
                      onPressed: busy ? null : _submit,
                      child: Text(busy
                          ? 'Đang gửi…'
                          : widget.mode == ShiftTaskEditorMode.create
                              ? 'Thêm việc'
                              : 'Gửi')),
                ])));
  }
}
