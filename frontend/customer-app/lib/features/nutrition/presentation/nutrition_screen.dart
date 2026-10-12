import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';
import 'nutrition_controller.dart';

class NutritionScreen extends ConsumerStatefulWidget {
  final String beneficiaryId;
  const NutritionScreen({super.key, required this.beneficiaryId});
  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen>
    with WidgetsBindingObserver {
  final _allergies = TextEditingController(),
      _conditions = TextEditingController(),
      _note = TextEditingController(),
      _instructions = TextEditingController();
  int? _loadedRevision;
  String _allergyStatus = 'unknown', _conditionStatus = 'unknown';
  bool _allergiesDirty = false,
      _conditionsDirty = false,
      _statusDirty = false,
      _conditionStatusDirty = false;
  bool _noteDirty = false, _instructionsDirty = false;
  VoidCallback? _closeSheet;
  bool _notesExpanded = false;
  bool get _dirty =>
      _allergiesDirty ||
      _conditionsDirty ||
      _statusDirty ||
      _conditionStatusDirty ||
      _noteDirty ||
      _instructionsDirty;
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
      _loadedRevision = null;
      for (final c in [_allergies, _conditions, _note, _instructions]) {
        c.clear();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller =
        ref.read(nutritionFlowProvider(widget.beneficiaryId).notifier);
    if (state == AppLifecycleState.resumed) {
      controller.resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      controller.suspend();
    }
  }

  void _populate(Map<String, dynamic> health) {
    final revision = (health['revision'] as num).toInt();
    if (_loadedRevision == revision) return;
    _loadedRevision = revision;
    String labels(Object? raw) => raw is List
        ? raw
            .map((e) => e is Map ? e['label'] ?? e['code'] ?? jsonEncode(e) : e)
            .join('; ')
        : '';
    _allergies.text = labels(health['allergies']);
    _conditions.text = labels(health['chronicConditions']);
    _note.text = health['generalNote']?.toString() ?? '';
    _instructions.text = health['careInstructions']?.toString() ?? '';
    _allergyStatus = health['allergyStatus']?.toString() ?? 'unknown';
    final history = health['healthHistory'];
    _conditionStatus = history is Map && history['nutrition'] is Map
        ? history['nutrition']['conditionsStatus']?.toString() ?? 'unknown'
        : 'unknown';
    _allergiesDirty = _conditionsDirty = _statusDirty =
        _conditionStatusDirty = _noteDirty = _instructionsDirty = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final c in [_allergies, _conditions, _note, _instructions]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(nutritionFlowProvider(widget.beneficiaryId));
    ref.listen(nutritionSessionProvider, (previousSession, nextSession) {
      _closeSheet?.call();
      _loadedRevision = null;
      for (final c in [_allergies, _conditions, _note, _instructions]) {
        c.clear();
      }
    });
    final controller =
        ref.read(nutritionFlowProvider(widget.beneficiaryId).notifier);
    final profile = ref
        .watch(beneficiaryStoreProvider)
        .where((b) => b.id == widget.beneficiaryId)
        .firstOrNull;
    final health = flow.health;
    if (health != null) _populate(health);
    return Scaffold(
      appBar: AppBar(title: const Text('Gợi ý thực đơn')),
      body: health == null
          ? Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: flow.loading
                      ? const CircularProgressIndicator()
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(flow.error ?? 'Hồ sơ không còn khả dụng.',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                              onPressed: controller.load,
                              child: const Text('Tải lại'))
                        ])))
          : ListView(padding: const EdgeInsets.all(20), children: [
              Text(
                  profile == null
                      ? 'Hồ sơ đang chọn'
                      : 'Thực đơn cho ${profile.name}',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                  'Kiểm tra thông tin sức khỏe trước khi xem gợi ý. Thông tin do bạn và gia đình cung cấp.'),
              if (flow.error != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(flow.error!,
                        style: const TextStyle(color: AppColors.error))),
              if (flow.loading)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator()),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                  key: ValueKey('allergy-$_loadedRevision'),
                  initialValue: _allergyStatus,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Dị ứng thực phẩm'),
                  items: const [
                    DropdownMenuItem(value: 'unknown', child: Text('Chưa rõ')),
                    DropdownMenuItem(
                        value: 'reported_present',
                        child: Text('Có dị ứng thực phẩm')),
                    DropdownMenuItem(
                        value: 'reported_none',
                        child: Text('Đã xác nhận không có'))
                  ],
                  onChanged: flow.loading
                      ? null
                      : (v) => setState(() {
                            _allergyStatus = v!;
                            _statusDirty = true;
                          })),
              const SizedBox(height: 12),
              if (_allergyStatus == 'reported_present' ||
                  _allergies.text.isNotEmpty)
                TextField(
                    controller: _allergies,
                    enabled: !flow.loading,
                    onChanged: (_) => setState(() => _allergiesDirty = true),
                    maxLength: 1000,
                    decoration: const InputDecoration(
                        labelText: 'Thực phẩm gây dị ứng',
                        helperText: 'Ngăn cách các thực phẩm bằng dấu ;')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                  key: ValueKey('conditions-$_loadedRevision'),
                  initialValue: ['unknown', 'reported_present', 'reported_none']
                          .contains(_conditionStatus)
                      ? _conditionStatus
                      : 'unknown',
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Thông tin bệnh lý hiện có'),
                  items: const [
                    DropdownMenuItem(
                        value: 'unknown',
                        child: Text('Chưa rõ / cần cập nhật')),
                    DropdownMenuItem(
                        value: 'reported_present',
                        child: Text('Có thông tin bệnh lý')),
                    DropdownMenuItem(
                        value: 'reported_none',
                        child: Text('Gia đình xác nhận chưa có bệnh lý'))
                  ],
                  onChanged: flow.loading
                      ? null
                      : (v) => setState(() {
                            _conditionStatus = v!;
                            _conditionStatusDirty = true;
                          })),
              if (_conditionStatus == 'reported_present' ||
                  _conditions.text.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextField(
                        controller: _conditions,
                        enabled: !flow.loading,
                        maxLength: 2000,
                        onChanged: (_) =>
                            setState(() => _conditionsDirty = true),
                        decoration: const InputDecoration(
                            labelText: 'Bệnh đã được thông báo',
                            helperText:
                                'Không nhập triệu chứng như một chẩn đoán.'))),
              const SizedBox(height: 12),
              ExpansionTile(
                  key: ValueKey('nutrition-notes-${widget.beneficiaryId}'),
                  initiallyExpanded: _notesExpanded,
                  onExpansionChanged: (expanded) => _notesExpanded = expanded,
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Lưu ý và hướng dẫn hiện có'),
                  subtitle:
                      const Text('Bổ sung khi cần; không bắt buộc nhập lại.'),
                  children: [
                    TextField(
                        controller: _note,
                        enabled: !flow.loading,
                        minLines: 2,
                        maxLines: 6,
                        maxLength: 4000,
                        onChanged: (_) => setState(() => _noteDirty = true),
                        decoration: const InputDecoration(
                            labelText: 'Lưu ý sức khỏe / triệu chứng chưa rõ')),
                    TextField(
                        controller: _instructions,
                        enabled: !flow.loading,
                        minLines: 2,
                        maxLines: 6,
                        maxLength: 4000,
                        onChanged: (_) =>
                            setState(() => _instructionsDirty = true),
                        decoration: const InputDecoration(
                            labelText: 'Hướng dẫn chăm sóc, ăn uống hiện có')),
                    if (health['healthHistory'] != null)
                      const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                              'Thông tin sức khỏe khác đã lưu được giữ nguyên khi cập nhật các mục trên.')),
                  ]),
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed:
                      flow.loading ? null : () => _save(controller, health),
                  child: const Text('Lưu phần thông tin đã cập nhật')),
              const SizedBox(height: 12),
              if (_dirty)
                const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                        'Lưu phần thông tin đã cập nhật trước khi kiểm tra và xem gợi ý.')),
              FilledButton(
                  onPressed: flow.loading || _dirty ? null : controller.assess,
                  child: const Text('Kiểm tra thông tin')),
              TextButton(
                  onPressed: flow.loading || _dirty
                      ? null
                      : () => _history(controller),
                  child: const Text('Xem thực đơn đã lưu')),
              const SizedBox(height: 24),
              if (flow.resource != null && !_dirty)
                ..._result(flow, controller),
            ]),
    );
  }

  List<String> _items(String text) =>
      text.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  void _save(NutritionFlowController c, Map<String, dynamic> health) {
    final changes = <String, dynamic>{};
    if (_allergiesDirty) changes['allergies'] = _items(_allergies.text);
    if (_conditionsDirty) {
      changes['chronicConditions'] = _items(_conditions.text);
    }
    if (_statusDirty) changes['foodAllergyStatus'] = _allergyStatus;
    if (_noteDirty) changes['generalNote'] = _note.text;
    if (_instructionsDirty) changes['careInstructions'] = _instructions.text;
    if (_conditionStatusDirty) {
      final history = health['healthHistory'];
      if (history != null && history is! Map) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Hồ sơ có dữ liệu sức khỏe cũ cần kiểm tra riêng. Các thông tin đó được giữ nguyên.')));
        return;
      }
      final map = Map<String, dynamic>.from(history as Map? ?? {});
      map['nutrition'] = {
        ...(map['nutrition'] is Map
            ? Map<String, dynamic>.from(map['nutrition'])
            : <String, dynamic>{}),
        'schemaVersion': 1,
        'conditionsStatus': _conditionStatus
      };
      changes['healthHistory'] = map;
    }
    if (changes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa có thông tin thay đổi.')));
      return;
    }
    c.saveHealth(changes);
  }

  List<Widget> _result(NutritionFlow flow, NutritionFlowController c) {
    final r = flow.resource!;
    final data = r['data'] as Map? ?? {};
    final decision = data['decision'] as Map? ?? {};
    final status = r['status']?.toString() ?? '';
    final state =
        status == 'stale' ? 'stale' : decision['state']?.toString() ?? status;
    final title = <String, String>{
          'queued': 'Đang chờ phân tích',
          'processing': 'Đang phân tích thông tin',
          'needs_information': 'Cần bổ sung thông tin',
          'needs_professional_guidance':
              'Cần hướng dẫn phù hợp trước khi gợi ý',
          'awaiting_confirmation': 'Kiểm tra bản tóm tắt',
          'eligible': 'Thông tin đã được xác nhận',
          'no_content': 'Chưa có công thức đã duyệt cho nhu cầu này',
          'no_match': 'Chưa tìm được món đáp ứng các yêu cầu',
          'failed': 'Chưa phân tích được thông tin',
          'stale': 'Thông tin đã thay đổi — cần kiểm tra lại',
          'suggested':
              status == 'saved' ? 'Thực đơn đã lưu' : 'Thực đơn được gợi ý'
        }[state] ??
        'Trạng thái: $status';
    const fields = {
      'foodAllergyStatus': 'Xác nhận tình trạng dị ứng thực phẩm',
      'conditionsStatus': 'Xác nhận thông tin bệnh lý hiện có',
      'chronicConditions': 'Bổ sung bệnh đã được thông báo',
      'allergies': 'Làm rõ thực phẩm gây dị ứng',
      'unresolvedHealthFacts':
          'Làm rõ triệu chứng hoặc thông tin chưa chắc chắn'
    };
    final widgets = <Widget>[
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12)
    ];
    for (final field in decision['missingFields'] as List? ?? []) {
      widgets.add(Text('• ${fields[field] ?? _fieldLabel(field.toString())}'));
    }
    if ((decision['conflicts'] as List? ?? []).isNotEmpty) {
      widgets.add(const Text(
          'Các nguồn thông tin đang khác nhau. Vui lòng kiểm tra lại hồ sơ; hệ thống giữ các hạn chế đã báo cáo.'));
    }
    if (state == 'needs_professional_guidance') {
      widgets.add(const Text(
          'Hồ sơ cần thêm hướng dẫn chuyên biệt hoặc đang ngoài phạm vi nội dung được hỗ trợ. Không tự đổi sang ăn mềm hay đặt giới hạn dinh dưỡng.'));
    }
    for (final fact in state == 'stale' ? [] : data['facts'] as List? ?? []) {
      if (fact is Map) {
        widgets.add(ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(fact['label']?.toString() ?? ''),
            subtitle: Text(
                '${_fieldLabel(fact['sourceKey']?.toString() ?? '')} · ${_assertion(fact['assertion'])} · ${_temporality(fact['temporality'])}')));
      }
    }
    if (state == 'failed') {
      widgets.add(Text(data['errorCode'] == 'nutrition.ai_unavailable'
          ? 'Dịch vụ AI chưa được cấu hình. Thông tin đã nhập vẫn được giữ.'
          : 'Phân tích chưa thành công. Thông tin đã nhập vẫn được giữ.'));
    }
    widgets.add(const SizedBox(height: 12));
    if (state == 'awaiting_confirmation') {
      widgets.add(FilledButton(
          onPressed: flow.loading ? null : c.confirm,
          child: const Text('Thông tin đúng, tiếp tục')));
    }
    if (state == 'eligible' && flow.recommendationsEnabled) {
      widgets.add(FilledButton(
          onPressed: flow.loading ? null : c.recommend,
          child: const Text('Xem gợi ý thực đơn')));
    }
    if (state == 'stale') {
      widgets.add(FilledButton(
          onPressed: flow.loading ? null : c.load,
          child: const Text('Kiểm tra lại hồ sơ')));
    }
    if (state == 'failed' && data['retryable'] == true) {
      widgets.add(OutlinedButton(
          onPressed: flow.loading ? null : () => c.assess(retryFailed: true),
          child: const Text('Thử phân tích lại')));
    }
    for (final meal in state == 'stale' ? [] : data['meals'] as List? ?? []) {
      if (meal is! Map) continue;
      const labels = {
        'breakfast': 'Bữa sáng',
        'lunch': 'Bữa trưa',
        'dinner': 'Bữa tối'
      };
      widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(labels[meal['mealType']] ?? 'Bữa ăn',
                style: Theme.of(context).textTheme.titleMedium),
            Text(meal['name']?.toString() ?? ''),
            Text('Khẩu phần: ${meal['servings']} phần'),
            for (final ingredient in meal['ingredients'] as List? ?? [])
              if (ingredient is Map)
                Text(
                    '${ingredient['name']}: ${ingredient['amount']} ${ingredient['unit']} (${ingredient['basis'] == 'cooked' ? 'đã chế biến' : 'trước chế biến'})'),
            const Text(
                'Được gợi ý vì đáp ứng các ràng buộc đã kiểm tra của hồ sơ này.'),
            const Text(
                'Điều cần lưu ý: dùng đúng công thức và khẩu phần đã kiểm tra.'),
            Text(
                'Cách chế biến: ${(meal['preparationSteps'] as List? ?? []).join('; ')}'),
            ..._nutrients(meal['nutrients']),
            Text('Nguồn: ${(meal['sources'] as List? ?? []).join('; ')}'),
            if (state == 'suggested' && status != 'saved')
              OutlinedButton(
                  onPressed: flow.loading
                      ? null
                      : () => _replace(c, meal['mealType'].toString()),
                  child: const Text('Chọn món thay thế')),
          ])));
    }
    if (state == 'suggested' && status != 'saved') {
      widgets.add(FilledButton(
          onPressed: flow.loading ? null : c.save,
          child: const Text('Lưu thực đơn')));
    }
    return widgets;
  }

  String _fieldLabel(String field) {
    if (field.startsWith('allergies')) return 'Dị ứng thực phẩm';
    if (field.startsWith('chronicConditions')) return 'Thông tin bệnh lý';
    return {
          'generalNote': 'Lưu ý sức khỏe',
          'careInstructions': 'Hướng dẫn chăm sóc',
          'mobilityNote': 'Khả năng vận động',
          'medications': 'Thuốc đang dùng',
          'healthHistory/nutrition/feedingRoute': 'Cách ăn uống',
          'healthHistory/nutrition/swallowingStatus': 'Khả năng nuốt',
          'healthHistory/nutrition/fluidRestriction': 'Hướng dẫn hạn chế nước',
          'healthHistory/nutrition/electrolyteRestriction':
              'Hướng dẫn về điện giải',
          'healthHistory/nutrition/symptoms': 'Triệu chứng đã báo cáo',
          'healthHistory/nutrition/guidance': 'Hướng dẫn ăn uống',
        }[field] ??
        'Thông tin sức khỏe cần được làm rõ';
  }

  String _assertion(Object? value) =>
      {
        'present': 'Đã báo cáo',
        'absent': 'Báo cáo không có',
        'uncertain': 'Chưa chắc chắn'
      }[value] ??
      'Cần làm rõ';
  String _temporality(Object? value) =>
      {
        'current': 'Hiện tại',
        'past': 'Trước đây',
        'unknown': 'Chưa rõ thời điểm'
      }[value] ??
      'Chưa rõ thời điểm';
  List<Widget> _nutrients(Object? raw) {
    const labels = {
      'energy_kcal': 'Năng lượng (kcal)',
      'protein_g': 'Đạm (g)',
      'carbohydrate_g': 'Carbohydrate (g)',
      'fat_g': 'Chất béo (g)',
      'fiber_g': 'Chất xơ (g)',
      'sodium_mg': 'Natri (mg)',
      'potassium_mg': 'Kali (mg)',
      'phosphorus_mg': 'Phospho (mg)',
      'fluid_ml': 'Dịch (ml)'
    };
    if (raw is! Map) {
      return [const Text('Chưa có thông tin dinh dưỡng mỗi phần.')];
    }
    final known = raw.entries.where((e) => labels.containsKey(e.key)).toList();
    return [
      const Text('Dinh dưỡng mỗi phần:'),
      for (final e in known)
        Text('${labels[e.key]}: ${e.value ?? 'Chưa có dữ liệu'}')
    ];
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
                            padding: EdgeInsets.all(24),
                            child: Text(
                                'Chưa có món thay thế đáp ứng các yêu cầu của thực đơn.')))
                    : ListView(children: [
                        const ListTile(title: Text('Món thay thế phù hợp')),
                        for (final recipe in options)
                          ListTile(
                              title: Text(recipe['name'].toString()),
                              subtitle:
                                  Text('Khẩu phần: ${recipe['servings']} phần'),
                              onTap: () => Navigator.pop(
                                  context, recipe['versionId'].toString()))
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
                              title: Text(
                                  'Ngày ${(plan['data'] as Map?)?['plannedDate'] ?? ''}'),
                              subtitle: Text(plan['status'] == 'stale'
                                  ? 'Cần kiểm tra lại thông tin'
                                  : 'Đã lưu'),
                              onTap: () =>
                                  Navigator.pop(context, plan['id'].toString()))
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
