using CareSitter.Modules.Support.Application.Chat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Queries.Chat;

internal sealed record ListSupportChatMessagesQuery(
    ChatActor Actor,
    Guid ConversationId,
    long? BeforeSequence,
    long? AfterSequence,
    long? HighWatermarkSequence,
    int Limit)
    : IRequest<Result<ChatPageResponse<ChatMessageResponse>>>;

internal sealed class ListSupportChatMessagesQueryHandler(ISupportChatQueries chat)
    : IRequestHandler<ListSupportChatMessagesQuery, Result<ChatPageResponse<ChatMessageResponse>>>
{
    public Task<Result<ChatPageResponse<ChatMessageResponse>>> Handle(
        ListSupportChatMessagesQuery request, CancellationToken ct) =>
        chat.MessagesAsync(request.Actor, request.ConversationId, request.BeforeSequence,
            request.AfterSequence, request.HighWatermarkSequence, request.Limit, ct);
}
