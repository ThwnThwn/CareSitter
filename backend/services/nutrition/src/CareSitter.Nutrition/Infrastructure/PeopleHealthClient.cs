using System.Net;
using CareSitter.Nutrition.Contracts;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class PeopleHealthClient(HttpClient client) : IPeopleHealthClient
{
    public async Task<BeneficiaryHealthSnapshot?> ReadAsync(Guid owner, Guid beneficiary, CancellationToken ct)
    {
        using var response = await client.GetAsync($"internal/v1/nutrition/owners/{owner}/beneficiaries/{beneficiary}/health-profile", ct);
        if (response.StatusCode == HttpStatusCode.NotFound) return null;
        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<BeneficiaryHealthSnapshot>(cancellationToken: ct);
        if (result is null || result.BeneficiaryId != beneficiary || result.Revision < 1) throw new HttpRequestException("Invalid People snapshot contract.");
        return result;
    }
}
