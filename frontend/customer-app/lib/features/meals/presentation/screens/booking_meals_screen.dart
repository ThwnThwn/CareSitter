import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/confirm_action_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/booking_meals_controller.dart';
import '../models/booking_meal_copy.dart';
import '../widgets/booking_meal_day.dart';
import '../widgets/booking_meal_share_options.dart';

class BookingMealsScreen extends ConsumerWidget {
  const BookingMealsScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = bookingMealsProvider(bookingId);
    final state = ref.watch(provider);
    final data = state.isReloading ? null : state.valueOrNull;
    final window = data?.shareWindow;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bữa ăn trong ca'),
        leading:
            AppBackButton(fallbackRoute: AppRoutes.bookingDetail(bookingId)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (state.isLoading)
                const LinearProgressIndicator(
                    semanticsLabel: 'Đang tải bữa ăn'),
              if (state.hasError && !state.isLoading)
                ListTile(
                  title: Text(mealLoadError(state.error!)),
                  trailing: IconButton(
                    tooltip: 'Tải lại bữa ăn',
                    onPressed: () => ref.invalidate(provider),
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              if (data != null) ...[
                if (window != null)
                  BookingMealShareOptions(
                    key: ValueKey(window),
                    data: data,
                    window: window,
                    disabled: state.isLoading,
                    onSelect: (plan) =>
                        _share(context, ref, plan.id, plan.plannedDate),
                  ),
                if (data.plans.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text('Ca này chưa có thực đơn được chia sẻ.'),
                  ),
                for (final plan in data.plans)
                  BookingMealDay(
                    key: ValueKey(plan.plannedDate),
                    plan: plan,
                    records: data.records
                        .where((r) => r.plannedDate == plan.plannedDate)
                        .toList(),
                    onRevoke: state.isLoading
                        ? null
                        : () => _revoke(context, ref, plan.plannedDate),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _share(
      BuildContext context, WidgetRef ref, String planId, String date) async {
    final session = _session(ref);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Chia sẻ thực đơn ngày ${mealDateLabel(date)}?'),
        content: const Text(
            'Người chăm sóc được phân công có thể xem món, khẩu phần, nguyên liệu và cách chuẩn bị trong ca.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Quay lại')),
          FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Chia sẻ')),
        ],
      ),
    );
    if (!context.mounted || confirmed != true || session != _session(ref)) {
      return;
    }
    final saved =
        await ref.read(bookingMealsProvider(bookingId).notifier).share(planId);
    if (context.mounted && saved) {
      _showSaved(context, 'Đã chia sẻ thực đơn cho ca.');
    }
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref, String date) async {
    final session = _session(ref);
    final confirmed = await showConfirmActionDialog(
      context,
      title: 'Thu hồi thực đơn ngày ${mealDateLabel(date)}?',
      message:
          'Người chăm sóc sẽ mất quyền xem và ghi thêm bữa theo thực đơn này. Gia đình vẫn xem được các ghi nhận đã lưu.',
      confirmLabel: 'Thu hồi',
      keepLabel: 'Giữ thực đơn',
    );
    if (!context.mounted || !confirmed || session != _session(ref)) return;
    final saved =
        await ref.read(bookingMealsProvider(bookingId).notifier).revoke(date);
    if (context.mounted && saved) _showSaved(context, 'Đã thu hồi thực đơn.');
  }

  (String?, int) _session(WidgetRef ref) => (
        ref.read(authStateProvider).valueOrNull?.userId,
        ref.read(authStateProvider.notifier).sessionGeneration,
      );

  void _showSaved(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
}
