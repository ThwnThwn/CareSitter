using CareSitter.Modules.Support.Application.Chat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.Chat;

internal sealed record ClaimSupportConversationCommand(
    ChatActor Actor,
    Guid ConversationId,
    long ExpectedVersion)
    : IRequest<Result<ChatConversationResponse>>;

internal sealed class ClaimSupportConversationCommandHandler(ISupportChatCommands chat)
    : IRequestHandler<ClaimSupportConversationCommand, Result<ChatConversationResponse>>
{
    public Task<Result<ChatConversationResponse>> Handle(
        ClaimSupportConversationCommand request, CancellationToken ct) =>
        chat.ClaimAsync(request.Actor, request.ConversationId, request.ExpectedVersion, ct);
}
