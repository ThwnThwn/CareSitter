namespace CareSitter.Nutrition.Contracts;

public interface ICurrentUser
{
    Guid? UserId { get; }
    IReadOnlyList<string> Roles { get; }
}
