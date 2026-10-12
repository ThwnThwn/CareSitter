using System.Net;
using System.Net.Http.Headers;
using CareSitter.Nutrition.Contracts;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class IdentitySessionClient(HttpClient client) : IIdentitySessionClient
{
    public async Task<bool> IsActiveAsync(string bearerToken, CancellationToken ct)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, "api/v1/auth/session");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", bearerToken);
        using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, ct);
        if (response.StatusCode is HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden) return false;
        if (response.StatusCode != HttpStatusCode.NoContent) throw new HttpRequestException("Identity session validation unavailable.");
        return true;
    }
}
