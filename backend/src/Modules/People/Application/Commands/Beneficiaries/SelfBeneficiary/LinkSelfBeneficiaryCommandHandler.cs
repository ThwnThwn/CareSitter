using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.SelfBeneficiary;

internal sealed class LinkSelfBeneficiaryCommandHandler(IPeopleRepository repository, ICurrentUser currentUser)
    : IRequestHandler<LinkSelfBeneficiaryCommand, Result<BeneficiaryResponse>>
{
    public async Task<Result<BeneficiaryResponse>> Handle(LinkSelfBeneficiaryCommand request, CancellationToken ct)
    {
        if (SelfBeneficiaryRules.Authorize(currentUser) is { } error) return error;
        var userId = currentUser.UserId!.Value;
        await using var tx = await repository.BeginUserScopeAsync(userId, ct);
        await repository.LockSelfBeneficiaryAsync(userId, ct);
        var existing = await repository.GetSelfBeneficiaryAsync(userId, ct);
        if (existing?.DeletedAt is not null) return SelfBeneficiaryRules.Archived();
        if (existing is not null && existing.Id != request.BeneficiaryId)
            return Error.Conflict("beneficiary.self_exists", "Đã có hồ sơ bản thân khác. Vui lòng tải lại thông tin.");
        var entity = await repository.GetBeneficiaryAsync(request.BeneficiaryId, userId, ct);
        if (entity is null) return PeopleErrors.NotFound();
        var marked = entity.MarkAsSelf();
        if (marked.IsFailure) return marked.Error;
        await repository.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return PeopleResponseMapper.ToResponse(entity);
    }
}
