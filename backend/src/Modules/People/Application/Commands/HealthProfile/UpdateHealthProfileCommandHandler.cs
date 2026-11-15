using System.Text.Json;
using CareSitter.Contracts.Nutrition;
using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.HealthProfile;

internal sealed class UpdateHealthProfileCommandHandler(IPeopleRepository repository,
    ICurrentUser user) : IRequestHandler<UpdateHealthProfileCommand, Result<BeneficiaryHealthSnapshot>>
{
    public async Task<Result<BeneficiaryHealthSnapshot>> Handle(UpdateHealthProfileCommand request, CancellationToken ct)
    {
        if (user.UserId is not { } owner) return Error.Unauthorized("nutrition.unauthenticated", "Vui lòng đăng nhập lại.");
        if (!user.Roles.Contains("CUSTOMER")) return Error.Forbidden("nutrition.forbidden", "Không có quyền cập nhật.");
        var changes = request.Changes;
        if (request.ExpectedHealthRevision < 1)
            return Error.Validation("nutrition.health_payload", "Thông tin cập nhật không hợp lệ.");
        var validation = HealthProfilePatch.Validate(changes);
        if (validation.IsFailure) return validation.Error;

        await using var transaction = await repository.BeginUserScopeAsync(owner, ct);
        var entity = await repository.GetBeneficiaryAsync(request.BeneficiaryId, owner, ct);
        if (entity is null) return Error.NotFound("nutrition.profile_not_found", "Hồ sơ không còn khả dụng.");
        if (entity.HealthProfileRevision != request.ExpectedHealthRevision)
            return Error.Conflict("nutrition.profile_changed", "Thông tin sức khỏe đã thay đổi. Vui lòng kiểm tra lại.");
        string? Text(string key, string? old) => !changes.TryGetProperty(key, out var v) ? old : v.ValueKind == JsonValueKind.Null ? null : v.GetString()?.Trim();
        string? Json(string key, string? old) => !changes.TryGetProperty(key, out var v) ? old : v.ValueKind == JsonValueKind.Null ? null : v.GetRawText();
        var allergies = Json("allergies", entity.Allergies);
        var history = Json("healthHistory", entity.HealthHistory);
        if (changes.TryGetProperty("nutritionProfile", out var profile))
        {
            var merged = HealthProfilePatch.MergeNutrition(history, profile);
            if (merged.IsFailure) return merged.Error;
            history = merged.Value;
        }
        var conditions = Json("chronicConditions", entity.ChronicConditions);
        var medications = Json("medications", entity.Medications);
        var historyChanged = changes.TryGetProperty("nutritionProfile", out _) || changes.TryGetProperty("healthHistory", out _);
        if ((historyChanged || changes.TryGetProperty("chronicConditions", out _)) &&
            HealthProfilePatch.ReportsNone(history, "conditionsStatus") && HealthProfilePatch.HasCurrentItems(conditions))
            return Error.Validation("nutrition.condition_conflict", "Danh sách vẫn có bệnh lý cần làm rõ. Vui lòng kiểm tra trước khi xác nhận không có.");
        if ((historyChanged || changes.TryGetProperty("medications", out _)) &&
            HealthProfilePatch.ReportsNone(history, "medicationsStatus") && HealthProfilePatch.HasCurrentItems(medications, medications: true))
            return Error.Validation("nutrition.medication_conflict", "Danh sách vẫn có thuốc đang dùng hoặc chưa rõ trạng thái. Vui lòng kiểm tra trước khi xác nhận không dùng thuốc.");
        var allergyStatus = Text("foodAllergyStatus", entity.FoodAllergyStatus) ?? "unknown";
        if (changes.TryGetProperty("allergies", out _) && !changes.TryGetProperty("foodAllergyStatus", out _)) allergyStatus = "unknown";
        if (allergyStatus == "reported_none" && HasItems(allergies))
            return Error.Validation("nutrition.allergy_conflict", "Danh sách dị ứng vẫn có dữ liệu. Vui lòng kiểm tra trước khi xác nhận không dị ứng.");
        if (allergyStatus == "reported_present" && !HasValidAllergies(allergies))
            return Error.Validation("nutrition.allergy_details", "Vui lòng nhập rõ thực phẩm gây dị ứng.");
        var result = entity.UpdateHealth(request.ExpectedHealthRevision,
            Text("generalNote", entity.GeneralNote), Text("careInstructions", entity.CareInstructions),
            history, allergies, conditions, medications, allergyStatus, owner, DateTimeOffset.UtcNow,
            changes.TryGetProperty("foodAllergyStatus", out _));
        if (result.IsFailure) return result.Error;
        await repository.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        return HealthProfileMapping.Snapshot(entity);
    }

    private static bool HasItems(string? json)
    {
        if (json is null) return false;
        using var document = JsonDocument.Parse(json);
        var value = document.RootElement;
        return value.ValueKind != JsonValueKind.Null && (value.ValueKind != JsonValueKind.Array || value.GetArrayLength() > 0);
    }

    private static bool HasValidAllergies(string? json)
    {
        if (json is null) return false;
        using var document = JsonDocument.Parse(json);
        var v = document.RootElement;
        return v.ValueKind == JsonValueKind.Array && v.GetArrayLength() is > 0 and <= 40 &&
            v.EnumerateArray().All(x => x.ValueKind == JsonValueKind.String &&
                !string.IsNullOrWhiteSpace(x.GetString()) && x.GetString()!.Length <= 100);
    }
}
