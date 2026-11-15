using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using CareSitter.Contracts.Nutrition;
using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.People.Application;

internal sealed class MealTasteFeedbackService(IPeopleRepository repository, IMealTasteFeedbackStore store,
    ICurrentUser user, IClock clock) : IMealTasteFeedbackService
{
    public async Task<Result<MealTasteFeedbackResponse>> SubmitAsync(MealTasteFeedbackProposal proposal, CancellationToken ct)
    {
        if (user.UserId is not { } actor) return Error.Unauthorized("nutrition.unauthenticated", "Vui lòng đăng nhập lại.");
        if (!user.IsInRole("CUSTOMER") || actor != proposal.OwnerId)
            return Error.Forbidden("nutrition.feedback_forbidden", "Không có quyền ghi phản hồi này.");
        if (proposal.IdempotencyKey == Guid.Empty || proposal.PlanId == Guid.Empty || proposal.RecipeVersionId == Guid.Empty ||
            proposal.Feedback is not ("liked" or "disliked" or "want_again") ||
            proposal.MealType is not ("breakfast" or "lunch" or "dinner") ||
            string.IsNullOrWhiteSpace(proposal.MealName) || proposal.MealName.Length > 255 ||
            proposal.PlannedDate > DateOnly.FromDateTime(clock.UtcNow.AddHours(7).DateTime))
            return Error.Validation("nutrition.feedback_invalid", "Chỉ ghi phản hồi cho món thuộc bữa ăn hôm nay hoặc ngày đã qua.");
        await using var transaction = await repository.BeginUserScopeAsync(proposal.OwnerId, ct);
        // Same beneficiary lock serializes proposals, approval and normal health edits.
        var beneficiary = await repository.GetBeneficiaryAsync(proposal.BeneficiaryId, proposal.OwnerId, ct);
        if (beneficiary is null) return Missing();
        var fingerprint = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(proposal))));
        var previous = await store.ByKeyAsync(proposal.OwnerId, proposal.BeneficiaryId, actor, proposal.IdempotencyKey, ct);
        if (previous is not null)
            return previous.Fingerprint == fingerprint ? Map(previous) :
                Error.Conflict("nutrition.feedback_key_conflict", "Khóa phản hồi đã được dùng cho nội dung khác.");
        var history = await store.ListAsync(proposal.OwnerId, proposal.BeneficiaryId, proposal.PlanId, ct);
        if (history.Count >= 100 || history.Any(x => x.RecipeVersionId == proposal.RecipeVersionId &&
                x.SubmittedBy == actor && x.Status != "rejected"))
            return Error.Conflict("nutrition.feedback_exists", "Món này đã có phản hồi. Vui lòng xem lại ghi nhận hiện có.");
        var feedback = MealTasteFeedback.Create(proposal.OwnerId, proposal.BeneficiaryId, proposal.PlanId,
            proposal.PlannedDate, proposal.RecipeVersionId, proposal.MealType, proposal.MealName, proposal.Feedback,
            actor, "CUSTOMER", proposal.IdempotencyKey, fingerprint, clock.UtcNow);
        store.Add(feedback);
        await repository.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        return Map(feedback);
    }

    internal static MealTasteFeedbackResponse Map(MealTasteFeedback x) => new(x.Id, x.PlanId, x.RecipeVersionId,
        x.MealType, x.MealName, x.Feedback, x.Status, x.SubmittedByRole, x.SubmittedAt, x.ReviewedAt, x.AppliedHealthRevision);
    internal static Error Missing() => Error.NotFound("nutrition.feedback_not_found", "Không tìm thấy hồ sơ hoặc phản hồi.");
}
