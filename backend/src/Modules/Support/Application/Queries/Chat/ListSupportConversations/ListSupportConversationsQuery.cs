using CareSitter.Modules.Support.Application.Chat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Queries.Chat;

internal sealed record ListSupportConversationsQuery(
    ChatActor Actor,
    string? Queue,
    DateTimeOffset? BeforeCreatedAt,
    Guid? BeforeId,
    int Limit)
    : IRequest<Result<ChatListResponse>>;

internal sealed class ListSupportConversationsQueryHandler(ISupportChatQueries chat)
    : IRequestHandler<ListSupportConversationsQuery, Result<ChatListResponse>>
{
    public Task<Result<ChatListResponse>> Handle(
        ListSupportConversationsQuery request, CancellationToken ct) =>
        chat.ListAsync(request.Actor, request.Queue, request.BeforeCreatedAt,
            request.BeforeId, request.Limit, ct);
}
