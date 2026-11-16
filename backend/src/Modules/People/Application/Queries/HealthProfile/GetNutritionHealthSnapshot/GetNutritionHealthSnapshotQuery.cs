using CareSitter.Contracts.Nutrition;
using MediatR;

namespace CareSitter.Modules.People.Application.Queries.HealthProfile;

internal sealed record GetNutritionHealthSnapshotQuery(Guid OwnerId, Guid BeneficiaryId)
    : IRequest<BeneficiaryHealthSnapshot?>;

internal sealed class GetNutritionHealthSnapshotQueryHandler(IBeneficiaryHealthSnapshotReader reader)
    : IRequestHandler<GetNutritionHealthSnapshotQuery, BeneficiaryHealthSnapshot?>
{
    public Task<BeneficiaryHealthSnapshot?> Handle(GetNutritionHealthSnapshotQuery request,
        CancellationToken ct) =>
        reader.ReadAsync(request.OwnerId, request.BeneficiaryId, ct);
}
