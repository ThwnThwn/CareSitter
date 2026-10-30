import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'support_chat_avatar.dart';
import 'support_chat_layout.dart';

class SupportChatHeader extends StatelessWidget implements PreferredSizeWidget {
  const SupportChatHeader({
    super.key,
    required this.leading,
    required this.status,
    required this.onRefresh,
    required this.onInfo,
    this.toolbarHeight = SupportChatLayout.headerHeight,
  });

  final Widget leading;
  final String status;
  final VoidCallback? onRefresh;
  final VoidCallback onInfo;
  final double toolbarHeight;

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
        toolbarHeight: toolbarHeight,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: leading,
        title: Row(
          children: [
            const SupportChatAvatar(size: SupportChatLayout.headerAvatarSize),
            const SizedBox(width: AppSpacing.compact),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Hỗ trợ CareSitter',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: AppFontSizes.s16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: AppSpacing.micro),
                  Text(status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: AppFontSizes.s12,
                          color: AppColors.primaryDark)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
              tooltip: 'Làm mới',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded)),
          IconButton(
              tooltip: 'Thông tin hội thoại',
              onPressed: onInfo,
              icon: const Icon(Icons.more_horiz_rounded)),
          const SizedBox(width: AppSpacing.xs),
        ],
      );
}
