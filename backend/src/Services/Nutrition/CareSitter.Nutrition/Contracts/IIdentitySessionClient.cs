namespace CareSitter.Nutrition.Contracts;

public interface IIdentitySessionClient
{
    Task<bool> IsActiveAsync(string bearerToken, CancellationToken ct);
}
