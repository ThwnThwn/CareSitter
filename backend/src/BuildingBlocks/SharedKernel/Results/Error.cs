namespace CareSitter.SharedKernel.Results;

/// <summary>
/// Loi nghiep vu co the tra ve tu domain/application. Code la dinh danh semantic de presentation tu map response.
/// </summary>
public sealed record Error(string Code, string Message, ErrorType Type)
{
    public static readonly Error None = new(string.Empty, string.Empty, ErrorType.Failure);

    public static Error NotFound(string code, string message) => new(code, message, ErrorType.NotFound);
    public static Error Validation(string code, string message) => new(code, message, ErrorType.Validation);
    public static Error Conflict(string code, string message) => new(code, message, ErrorType.Conflict);
    public static Error Forbidden(string code, string message) => new(code, message, ErrorType.Forbidden);
    public static Error Unauthorized(string code, string message) => new(code, message, ErrorType.Unauthorized);
    public static Error Failure(string code, string message) => new(code, message, ErrorType.Failure);
    public static Error Unavailable(string code, string message) => new(code, message, ErrorType.Unavailable);
}

public enum ErrorType
{
    Failure = 0,
    Validation = 1,
    NotFound = 2,
    Conflict = 3,
    Forbidden = 4,
    Unavailable = 5,
    Unauthorized = 6
}
