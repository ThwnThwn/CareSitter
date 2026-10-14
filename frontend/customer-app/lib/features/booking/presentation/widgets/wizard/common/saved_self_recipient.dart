import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';
import '../../../controllers/self_recipient_controller.dart';

class SavedSelfRecipient extends ConsumerWidget {
  const SavedSelfRecipient(
      {super.key, required this.selected});
  final SelfRecipient selected;
  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final profile = selected.profile;
    ref.read(beneficiaryStoreProvider.notifier).acceptSaved(profile);
    final user = ref.read(authStateProvider).valueOrNull?.userId;
    await context.push('/beneficiaries/${profile.id}/edit');
    if (!context.mounted ||
        ref.read(authStateProvider).valueOrNull?.userId != user) {
      return;
    }
    try {
      final saved = await ref
          .read(beneficiaryStoreProvider.notifier)
          .fetchProfile(profile.id);
      if (!context.mounted ||
          ref.read(authStateProvider).valueOrNull?.userId != user) {
        return;
      }
      ref.read(selfRecipientProvider.notifier).acceptExisting(saved);
      ref.invalidate(bookingRecipientsProvider);
    } catch (_) {
      if (context.mounted) ref.read(selfRecipientProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = selected.profile;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Tôi — ${profile.name}',
          style: Theme.of(context).textTheme.titleMedium),
      Text('${profile.ageLabel} • ${profile.careLevelLabel}'),
      if (profile.condition.isNotEmpty) Text(profile.condition),
      if (profile.notes.isNotEmpty) Text(profile.notes),
      for (final contact in profile.emergencyContacts)
        Text('${contact.name}: ${contact.phone}'),
      if (!selected.isComplete)
        const Text(
            'Vui lòng bổ sung họ tên và hai liên hệ khẩn cấp trước khi tiếp tục.'),
      TextButton.icon(
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Sửa thông tin chăm sóc'),
          onPressed: () => _edit(context, ref)),
      if (selected.kind == SelfRecipientKind.link)
        TextButton(
            onPressed: () =>
                ref.read(selfRecipientProvider.notifier).useDraft(),
            child: const Text('Dùng thông tin tài khoản')),
    ]);
  }
}
