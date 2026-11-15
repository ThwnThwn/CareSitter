using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;

namespace CareSitter.ApiHost.Security;

public sealed class NutritionServiceAuthenticationHandler(IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,UrlEncoder encoder,IConfiguration configuration) : AuthenticationHandler<AuthenticationSchemeOptions>(options,logger,encoder)
{
    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var expected=configuration["NutritionIntegration:ServiceKey"];
        var actual=Request.Headers["X-Nutrition-Service-Key"].ToString();
        if(expected?.Length is not (>=32 and <=256)||actual.Length>256||
            !CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(expected),Encoding.UTF8.GetBytes(actual)))
            return Task.FromResult(AuthenticateResult.Fail("Invalid nutrition service credential."));
        var identity=new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier,"nutrition-service")],Scheme.Name);
        return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(new ClaimsPrincipal(identity),Scheme.Name)));
    }
}
