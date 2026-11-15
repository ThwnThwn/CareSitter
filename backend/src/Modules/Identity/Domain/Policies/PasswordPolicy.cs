using System.Text;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Domain.Policies;

public static class PasswordPolicy
{
    public static Result Validate(string? password)
    {
        if (string.IsNullOrWhiteSpace(password) || password.Length < 8 ||
            !password.Any(char.IsUpper) || !password.Any(char.IsDigit))
            return Error.Validation("password.policy",
                "Mật khẩu cần ít nhất 8 ký tự, gồm một chữ hoa và một chữ số.");
        // BCrypt chỉ sử dụng tối đa 72 byte, không cho phép cắt ngầm mật khẩu.
        if (Encoding.UTF8.GetByteCount(password) > 72)
            return Error.Validation("password.too_long", "Mật khẩu không được vượt quá 72 byte UTF-8.");
        return Result.Success();
    }
}
