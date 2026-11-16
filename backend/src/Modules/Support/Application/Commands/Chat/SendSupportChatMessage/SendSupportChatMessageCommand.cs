using CareSitter.Modules.Support.Application.Chat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.Chat;

internal sealed record SendSupportChatMessageCommand(
    ChatActor Actor,
    Guid ConversationId,
    Guid IdempotencyKey,
    string Body)
    : IRequest<Result<ChatMessageResponse>>;

internal sealed class SendSupportChatMessageCommandHandler(ISupportChatCommands chat)
    : IRequestHandler<SendSupportChatMessageCommand, Result<ChatMessageResponse>>
{
    public Task<Result<ChatMessageResponse>> Handle(
        SendSupportChatMessageCommand request, CancellationToken ct) =>
        chat.SendAsync(request.Actor, request.ConversationId, request.IdempotencyKey, request.Body, ct);
}
