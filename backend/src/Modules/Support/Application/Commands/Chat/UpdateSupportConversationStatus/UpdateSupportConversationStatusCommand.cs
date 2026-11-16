using CareSitter.Modules.Support.Application.Chat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.Chat;

internal sealed record UpdateSupportConversationStatusCommand(
    ChatActor Actor,
    Guid ConversationId,
    string Status,
    long ExpectedVersion,
    string Reason)
    : IRequest<Result<ChatConversationResponse>>;

internal sealed class UpdateSupportConversationStatusCommandHandler(ISupportChatCommands chat)
    : IRequestHandler<UpdateSupportConversationStatusCommand, Result<ChatConversationResponse>>
{
    public Task<Result<ChatConversationResponse>> Handle(
        UpdateSupportConversationStatusCommand request, CancellationToken ct) =>
        chat.StatusAsync(request.Actor, request.ConversationId, request.Status, request.ExpectedVersion, request.Reason, ct);
}
