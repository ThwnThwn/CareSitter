import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../application/family_contact_store.dart';

Future<FamilyContactModel?> pickFamilyContact(
  BuildContext context,
  WidgetRef ref,
) =>
    showModalBottomSheet<FamilyContactModel>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final contacts = ref.watch(familyContactsProvider);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: contacts.when(
                loading: () => const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SizedBox(
                  height: 180,
                  child: Center(
                    child:
                        Text('Không tải được danh bạ gia đình. Hãy nhập tay.'),
                  ),
                ),
                data: (items) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Danh bạ gia đình',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      items.isEmpty
                          ? 'Chưa có liên hệ nào. Bạn có thể nhập tay rồi lưu lại để dùng lần sau.'
                          : 'Chọn một người để điền nhanh họ tên và số điện thoại.',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                            child: Icon(Icons.people_outline,
                                size: 42, color: AppColors.textHint)),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final contact = items[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.primaryContainer,
                                child: Icon(Icons.person_outline,
                                    color: AppColors.primary),
                              ),
                              title: Text(contact.fullName),
                              subtitle: Text(contact.phoneNumber),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context).pop(contact),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
