import 'dart:math' as math;
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/utils/date_formatter.dart';
import 'package:caregiver_app/features/support_chat/data/support_chat_repository.dart';
import 'package:flutter/material.dart';
import 'support_chat_avatar.dart';
import 'support_chat_layout.dart';

class SupportChatMessage extends StatelessWidget {
  const SupportChatMessage({
    super.key,
    required this.message,
    this.showAvatar = true,
  });

  final SupportMessage message;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final own = message.senderRole != 'ADMIN';
    final time = formatClock(message.createdAt.toLocal());
    final avatar = showAvatar
        ? SupportChatAvatar(isOwn: own)
        : const SizedBox(width: SupportChatLayout.avatarSize);
    return LayoutBuilder(builder: (context, constraints) {
      final width = math.min(
          SupportChatLayout.maxBubbleWidth,
          (constraints.maxWidth -
                  SupportChatLayout.avatarSize -
                  AppSpacing.sm) *
              SupportChatLayout.bubbleWidthRatio);
      return Semantics(
        container: true,
        child: Padding(
          padding: EdgeInsets.only(
              top: showAvatar ? AppSpacing.compact : AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment:
                own ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!own) ...[avatar, const SizedBox(width: AppSpacing.sm)],
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: width),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color:
                          own ? AppColors.primaryContainer : AppColors.surface,
                      border: own ? null : Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(AppRadius.lg),
                        topRight: const Radius.circular(AppRadius.lg),
                        bottomLeft:
                            Radius.circular(own ? AppRadius.lg : AppRadius.xs),
                        bottomRight:
                            Radius.circular(own ? AppRadius.xs : AppRadius.lg),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.inset,
                          vertical: AppSpacing.compact),
                      child: _MessageContent(
                          message: message, time: time, own: own),
                    ),
                  ),
                ),
              ),
              if (own) ...[const SizedBox(width: AppSpacing.sm), avatar],
            ],
          ),
        ),
      );
    });
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.message,
    required this.time,
    required this.own,
  });
  final SupportMessage message;
  final String time;
  final bool own;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(message.body,
              semanticsLabel:
                  'Tin nhắn của ${own ? 'bạn' : 'CareSitter'} lúc $time. ${message.body}',
              style: const TextStyle(
                  fontSize: AppFontSizes.s15,
                  height: 1.5,
                  color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.xs),
          ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time,
                    style: const TextStyle(
                        fontSize: AppFontSizes.s12,
                        color: AppColors.textSecondary)),
                if (own) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.check_rounded,
                      size: AppFontSizes.s16, color: AppColors.primary),
                ],
              ],
            ),
          ),
        ],
      );
}
