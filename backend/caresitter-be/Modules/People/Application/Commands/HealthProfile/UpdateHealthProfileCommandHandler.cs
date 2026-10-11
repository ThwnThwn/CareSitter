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
    private static readonly HashSet<string> Fields = ["generalNote", "careInstructions", "healthHistory",
        "allergies", "chronicConditions", "medications", "foodAllergyStatus"];

    public async Task<Result<BeneficiaryHealthSnapshot>> Handle(UpdateHealthProfileCommand request, CancellationToken ct)
    {
        if (user.UserId is not { } owner) return Error.Unauthorized("nutrition.unauthenticated", "Vui lòng đăng nhập lại.");
        if (!user.Roles.Contains("CUSTOMER")) return Error.Forbidden("nutrition.forbidden", "Không có quyền cập nhật.");
        var changes = request.Changes;
        if (request.ExpectedHealthRevision < 1 || changes.ValueKind != JsonValueKind.Object ||
            changes.GetRawText().Length > 16000 || changes.EnumerateObject().Any(x => !Fields.Contains(x.Name)) ||
            changes.EnumerateObject().Select(x => x.Name).Distinct().Count() != changes.EnumerateObject().Count())
            return Error.Validation("nutrition.health_payload", "Thông tin cập nhật không hợp lệ.");
        foreach (var key in new[] { "generalNote", "careInstructions", "foodAllergyStatus" })
            if (changes.TryGetProperty(key, out var text) && text.ValueKind is not (JsonValueKind.Null or JsonValueKind.String))
                return Error.Validation("nutrition.health_payload", "Định dạng thông tin không hợp lệ.");
        foreach (var key in new[] { "generalNote", "careInstructions" })
            if (changes.TryGetProperty(key, out var text) && text.ValueKind == JsonValueKind.String && text.GetString()!.Length > 4000)
                return Error.Validation("nutrition.health_length", "Ghi chú tối đa 4.000 ký tự.");

        await using var transaction = await repository.BeginUserScopeAsync(owner, ct);
        var entity = await repository.GetBeneficiaryAsync(request.BeneficiaryId, owner, ct);
        if (entity is null) return Error.NotFound("nutrition.profile_not_found", "Hồ sơ không còn khả dụng.");
        string? Text(string key, string? old) => !changes.TryGetProperty(key, out var v) ? old : v.ValueKind == JsonValueKind.Null ? null : v.GetString()?.Trim();
        string? Json(string key, string? old) => !changes.TryGetProperty(key, out var v) ? old : v.ValueKind == JsonValueKind.Null ? null : v.GetRawText();
        var allergies = Json("allergies", entity.Allergies);
        var allergyStatus = Text("foodAllergyStatus", entity.FoodAllergyStatus) ?? "unknown";
        if (changes.TryGetProperty("allergies", out _) && !changes.TryGetProperty("foodAllergyStatus", out _)) allergyStatus = "unknown";
        if (allergyStatus == "reported_none" && HasItems(allergies))
            return Error.Validation("nutrition.allergy_conflict", "Danh sách dị ứng vẫn có dữ liệu. Vui lòng kiểm tra trước khi xác nhận không dị ứng.");
        if (allergyStatus == "reported_present" && !HasValidAllergies(allergies))
            return Error.Validation("nutrition.allergy_details", "Vui lòng nhập rõ thực phẩm gây dị ứng.");
        var result = entity.UpdateHealth(request.ExpectedHealthRevision,
            Text("generalNote", entity.GeneralNote), Text("careInstructions", entity.CareInstructions),
            Json("healthHistory", entity.HealthHistory), allergies, Json("chronicConditions", entity.ChronicConditions),
            Json("medications", entity.Medications), allergyStatus, owner, DateTimeOffset.UtcNow,
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
