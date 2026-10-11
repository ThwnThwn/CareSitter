using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Primitives;

namespace CareSitter.Nutrition.Application;

internal static class NutritionAccessRules
{
    public static Error? Check(ICurrentUser user, INutritionFeatures features, bool write = false)
    {
        if (user.UserId is null) return Error.Unauthorized("nutrition.unauthenticated", "Vui lòng đăng nhập lại.");
        if (!user.Roles.Contains("CUSTOMER")) return Error.Forbidden("nutrition.forbidden", "Không có quyền truy cập.");
        if (!features.Enabled || (write && !features.AssessmentsEnabled)) return Error.Unavailable("nutrition.disabled", "Tính năng thực đơn chưa được mở.");
        return null;
    }
    public static Error Missing() => Error.NotFound("nutrition.profile_not_found", "Hồ sơ hoặc nội dung không còn khả dụng.");
    public static Error Changed() => Error.Conflict("nutrition.profile_changed", "Thông tin sức khỏe đã thay đổi. Vui lòng kiểm tra lại.");
    public static Error ContentChanged() => Error.Conflict("nutrition.content_changed", "Nội dung thực đơn đã thay đổi. Vui lòng lấy gợi ý mới.");
}
