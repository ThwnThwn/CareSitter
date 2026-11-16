using CareSitter.Modules.Support.Application.Chat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Queries.Chat;

internal sealed record ListSupportChatActivitiesQuery(
    ChatActor Actor,
    Guid ConversationId,
    DateTimeOffset? BeforeCreatedAt,
    Guid? BeforeId,
    int Limit)
    : IRequest<Result<ChatActivityListResponse>>;

internal sealed class ListSupportChatActivitiesQueryHandler(ISupportChatQueries chat)
    : IRequestHandler<ListSupportChatActivitiesQuery, Result<ChatActivityListResponse>>
{
    public Task<Result<ChatActivityListResponse>> Handle(
        ListSupportChatActivitiesQuery request, CancellationToken ct) =>
        chat.ActivitiesAsync(request.Actor, request.ConversationId, request.BeforeCreatedAt,
            request.BeforeId, request.Limit, ct);
}
