namespace CareSitter.Nutrition.Application;

public sealed class HealthParserException(string code, bool retryable) : Exception(code)
{
    public string Code { get; } = code;
    public bool Retryable { get; } = retryable;
}
