import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../../data/models/booking_meal_plan_model.dart';
import '../../data/models/booking_meal_record_model.dart';
import '../models/booking_meal_copy.dart';

class BookingMealDay extends StatelessWidget {
  const BookingMealDay({
    super.key,
    required this.plan,
    required this.records,
    this.onRevoke,
  });
  final BookingMealPlanModel plan;
  final List<BookingMealRecordModel> records;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final status = switch (plan.status) {
      'revoked' => 'Đã thu hồi',
      'stale' => 'Cần kiểm tra và chia sẻ lại',
      _ => 'Đã chia sẻ',
    };
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.compact),
      initiallyExpanded: true,
      title: Text(mealDateLabel(plan.plannedDate)),
      subtitle: Text(status),
      children: [
        for (final meal in plan.meals)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(meal.name),
            subtitle:
                Text('${mealTypeLabel(meal.mealType)} · ${meal.servings} phần'),
          ),
        if (records.isNotEmpty) ...[
          const Divider(),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Ghi nhận của người chăm sóc',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          for (final record in records) _RecordTile(record: record),
        ],
        if (plan.revokedAt == null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onRevoke,
              child: const Text('Thu hồi thực đơn'),
            ),
          ),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});
  final BookingMealRecordModel record;

  @override
  Widget build(BuildContext context) {
    final latest =
        '${mealTypeLabel(record.mealType)} · ${mealOutcomeLabel(record.outcome)}';
    if (record.corrections.isEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(latest),
        subtitle: record.note == null ? null : Text(record.note!),
      );
    }
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(latest),
      subtitle: Text([
        if (record.note != null) record.note!,
        'Lịch sử đính chính'
      ].join('\n')),
      children: [
        ListTile(
          title: Text(
              'Ghi nhận ban đầu · ${mealOutcomeLabel(record.originalOutcome ?? record.outcome)}'),
          subtitle:
              record.originalNote == null ? null : Text(record.originalNote!),
        ),
        for (final item in record.corrections)
          ListTile(
            title: Text(mealOutcomeLabel(item.outcome)),
            subtitle: Text(
                [item.reason, if (item.note != null) item.note!].join('\n')),
          ),
      ],
    );
  }
}
