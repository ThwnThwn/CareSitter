import 'package:flutter/material.dart';
import '../../data/models/health_profile_model.dart';

class NutritionNotesFields extends StatefulWidget {
  const NutritionNotesFields(
      {super.key,
      required this.health,
      required this.enabled,
      required this.onChanged});
  final HealthProfileModel health;
  final bool enabled;
  final void Function(String, String) onChanged;
  @override
  State<NutritionNotesFields> createState() => _NutritionNotesFieldsState();
}

class _NutritionNotesFieldsState extends State<NutritionNotesFields> {
  final _note = TextEditingController(),
      _instructions = TextEditingController();
  @override
  void initState() {
    super.initState();
    _note.text = widget.health['generalNote']?.toString() ?? '';
    _instructions.text = widget.health['careInstructions']?.toString() ?? '';
  }

  @override
  void dispose() {
    _note.dispose();
    _instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Lưu ý và hướng dẫn hiện có'),
          subtitle: const Text('Bổ sung khi cần; không bắt buộc nhập lại.'),
          children: [
            TextField(
                controller: _note,
                enabled: widget.enabled,
                minLines: 2,
                maxLines: 6,
                maxLength: 4000,
                onChanged: (v) => widget.onChanged('generalNote', v),
                decoration: const InputDecoration(
                    labelText: 'Lưu ý sức khỏe / triệu chứng chưa rõ')),
            TextField(
                controller: _instructions,
                enabled: widget.enabled,
                minLines: 2,
                maxLines: 6,
                maxLength: 4000,
                onChanged: (v) => widget.onChanged('careInstructions', v),
                decoration: const InputDecoration(
                    labelText: 'Hướng dẫn chăm sóc, ăn uống hiện có')),
            if (widget.health['healthHistory'] != null)
              const Text(
                  'Thông tin sức khỏe khác đã lưu được giữ nguyên khi cập nhật các mục trên.'),
          ]);
}
