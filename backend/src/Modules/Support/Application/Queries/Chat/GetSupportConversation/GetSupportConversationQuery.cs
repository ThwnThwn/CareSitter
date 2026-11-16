using CareSitter.Modules.Support.Application.Chat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Queries.Chat;

internal sealed record GetSupportConversationQuery(
    ChatActor Actor,
    Guid ConversationId)
    : IRequest<Result<ChatConversationResponse>>;

internal sealed class GetSupportConversationQueryHandler(ISupportChatQueries chat)
    : IRequestHandler<GetSupportConversationQuery, Result<ChatConversationResponse>>
{
    public Task<Result<ChatConversationResponse>> Handle(
        GetSupportConversationQuery request, CancellationToken ct) =>
        chat.GetAsync(request.Actor, request.ConversationId, ct);
}
