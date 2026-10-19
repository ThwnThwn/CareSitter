part of 'booking_chat_screen.dart';

extension on _BookingChatScreenState {
  Widget _buildInputBar(BookingChatState chat) {
    final templates = chat.meta?.quickTemplates ?? const [];
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.surfaceVariant, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (templates.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                scrollDirection: Axis.horizontal,
                itemCount: templates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _QuickMessageChip(
                  label: templates[i].body,
                  onTap: chat.busy ? null : () => _ctrl.sendQuick(templates[i]),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _draft,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      hintStyle:
                          const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _draft,
                  builder: (_, val, __) => _SendButton(
                    sending: chat.busy,
                    enabled: val.text.trim().isNotEmpty,
                    onTap: _send,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
