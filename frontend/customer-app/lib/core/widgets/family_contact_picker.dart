import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/theme/app_theme.dart';

Future<T?> pickFamilyContact<T>(BuildContext context, WidgetRef ref,
        {required ProviderListenable<AsyncValue<List<T>>> provider,
        required String Function(T) name,
        required String Function(T) phone}) =>
    showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final contacts = ref.watch(provider);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.section,
                  AppSpacing.xs, AppSpacing.section, AppSpacing.lg),
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
                            fontSize: AppFontSizes.s20,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.tight),
                    Text(
                      items.isEmpty
                          ? 'Chưa có liên hệ nào. Bạn có thể nhập tay rồi lưu lại để dùng lần sau.'
                          : 'Chọn một người để điền nhanh họ tên và số điện thoại.',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.compact),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.comfortable),
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
                              title: Text(name(contact)),
                              subtitle: Text(phone(contact)),
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
