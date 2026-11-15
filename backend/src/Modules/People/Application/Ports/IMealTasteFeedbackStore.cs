using CareSitter.Modules.People.Domain;

namespace CareSitter.Modules.People.Application;

internal interface IMealTasteFeedbackStore
{
    Task<MealTasteFeedback?> ByKeyAsync(Guid owner, Guid beneficiary, Guid actor, Guid key, CancellationToken ct);
    Task<MealTasteFeedback?> FindAsync(Guid owner, Guid beneficiary, Guid id, CancellationToken ct);
    Task<IReadOnlyList<MealTasteFeedback>> ListAsync(Guid owner, Guid beneficiary, Guid plan, CancellationToken ct);
    void Add(MealTasteFeedback feedback);
}
