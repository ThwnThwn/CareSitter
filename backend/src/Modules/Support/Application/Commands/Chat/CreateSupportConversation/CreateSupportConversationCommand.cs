using CareSitter.Modules.Support.Application.Chat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.Chat;

internal sealed record CreateSupportConversationCommand(
    ChatActor Actor,
    Guid IdempotencyKey,
    ChatCreateRequest Conversation)
    : IRequest<Result<ChatCreateResponse>>;

internal sealed class CreateSupportConversationCommandHandler(ISupportChatCommands chat)
    : IRequestHandler<CreateSupportConversationCommand, Result<ChatCreateResponse>>
{
    public Task<Result<ChatCreateResponse>> Handle(
        CreateSupportConversationCommand request, CancellationToken ct) =>
        chat.CreateAsync(request.Actor, request.IdempotencyKey, request.Conversation, ct);
}
