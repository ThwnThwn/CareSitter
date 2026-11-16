using CareSitter.Modules.Support.Application.Chat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.Chat;

internal sealed record TransferSupportConversationCommand(
    ChatActor Actor,
    Guid ConversationId,
    Guid TargetAdminId,
    bool Takeover,
    long ExpectedVersion,
    string Reason)
    : IRequest<Result<ChatConversationResponse>>;

internal sealed class TransferSupportConversationCommandHandler(ISupportChatCommands chat)
    : IRequestHandler<TransferSupportConversationCommand, Result<ChatConversationResponse>>
{
    public Task<Result<ChatConversationResponse>> Handle(
        TransferSupportConversationCommand request, CancellationToken ct) =>
        chat.TransferAsync(request.Actor, request.ConversationId, request.TargetAdminId,
            request.Takeover, request.ExpectedVersion, request.Reason, ct);
}
