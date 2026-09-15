using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.CreateDispute;

internal sealed class CreateDisputeCommandHandler(
    ISupportRepository repository,
    ICurrentUser currentUser) : IRequestHandler<CreateDisputeCommand, Result<DisputeResponse>>
{
    public async Task<Result<DisputeResponse>> Handle(
        CreateDisputeCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return SupportErrors.Unauthenticated();

        var exists = await repository.DisputeExistsAsync(request.BookingId, ct);
        if (exists) return SupportErrors.DisputeAlreadyExists();

        var created = Dispute.Create(request.BookingId, userId,
            request.Reason, request.Description);
        if (created.IsFailure) return created.Error;

        repository.AddDispute(created.Value);
        await repository.SaveChangesAsync(ct);
        return SupportResponseMapper.ToResponse(created.Value);
    }
}
