import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'support_chat_layout.dart';

class SupportChatAvatar extends StatelessWidget {
  const SupportChatAvatar({
    super.key,
    this.isOwn = false,
    this.size = SupportChatLayout.avatarSize,
  });

  final bool isOwn;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOwn ? AppColors.primary : AppColors.primaryContainer,
          ),
          child: Icon(
            isOwn ? Icons.person_rounded : Icons.support_agent_rounded,
            size: size * 0.58,
            color: isOwn ? AppColors.onPrimary : AppColors.primary,
          ),
        ),
      );
}
