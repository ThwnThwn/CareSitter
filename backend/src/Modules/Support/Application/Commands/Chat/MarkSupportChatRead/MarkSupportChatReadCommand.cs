using CareSitter.Modules.Support.Application.Chat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.Chat;

internal sealed record MarkSupportChatReadCommand(
    ChatActor Actor,
    Guid ConversationId,
    long LastReadSequence)
    : IRequest<Result<ChatConversationResponse>>;

internal sealed class MarkSupportChatReadCommandHandler(ISupportChatCommands chat)
    : IRequestHandler<MarkSupportChatReadCommand, Result<ChatConversationResponse>>
{
    public Task<Result<ChatConversationResponse>> Handle(
        MarkSupportChatReadCommand request, CancellationToken ct) =>
        chat.ReadAsync(request.Actor, request.ConversationId, request.LastReadSequence, ct);
}
