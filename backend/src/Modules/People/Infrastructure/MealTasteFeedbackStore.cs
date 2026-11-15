using CareSitter.Modules.People.Application;
using CareSitter.Modules.People.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.People.Infrastructure;

internal sealed class MealTasteFeedbackStore(PeopleDbContext db) : IMealTasteFeedbackStore
{
    public Task<MealTasteFeedback?> ByKeyAsync(Guid owner, Guid beneficiary, Guid actor, Guid key, CancellationToken ct) =>
        db.MealTasteFeedback.SingleOrDefaultAsync(x => x.OwnerId == owner && x.BeneficiaryId == beneficiary && x.SubmittedBy == actor && x.IdempotencyKey == key, ct);
    public Task<MealTasteFeedback?> FindAsync(Guid owner, Guid beneficiary, Guid id, CancellationToken ct) =>
        db.MealTasteFeedback.SingleOrDefaultAsync(x => x.Id == id && x.OwnerId == owner && x.BeneficiaryId == beneficiary, ct);
    public async Task<IReadOnlyList<MealTasteFeedback>> ListAsync(Guid owner, Guid beneficiary, Guid plan, CancellationToken ct) =>
        await db.MealTasteFeedback.Where(x => x.OwnerId == owner && x.BeneficiaryId == beneficiary && x.PlanId == plan)
            .OrderByDescending(x => x.SubmittedAt).Take(100).ToArrayAsync(ct);
    public void Add(MealTasteFeedback feedback) => db.MealTasteFeedback.Add(feedback);
}
