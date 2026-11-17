import '../data/booking_chat_meta.dart';
import '../data/booking_chat_message.dart';

class BookingChatState {
  const BookingChatState({
    this.loading = true,
    this.busy = false,
    this.error,
    this.meta,
    this.messages = const [],
    this.previousCursor,
    this.hasMoreBefore = false,
  });

  final bool loading;
  final bool busy;
  final String? error;
  final BookingChatMeta? meta;
  final List<BookingChatMessage> messages;
  final String? previousCursor;
  final bool hasMoreBefore;

  int get unreadCount => meta?.unreadCount ?? 0;
  bool get canSend => meta?.canSend == true;
  bool get canRead => meta?.canRead == true;
  bool get featureEnabled => meta?.featureEnabled == true;
  bool get hasChat => meta?.hasChat == true;

  BookingChatState copyWith({
    bool? loading,
    bool? busy,
    String? error,
    bool clearError = false,
    BookingChatMeta? meta,
    List<BookingChatMessage>? messages,
    String? previousCursor,
    bool clearPreviousCursor = false,
    bool? hasMoreBefore,
  }) => BookingChatState(
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    error: clearError ? null : error ?? this.error,
    meta: meta ?? this.meta,
    messages: messages ?? this.messages,
    previousCursor: clearPreviousCursor
        ? null
        : previousCursor ?? this.previousCursor,
    hasMoreBefore: hasMoreBefore ?? this.hasMoreBefore,
  );
}

// ---------------------------------------------------------------------------
// Controller
