using System.Security.Claims;
using CareSitter.Infrastructure.Security;
using Microsoft.AspNetCore.Http;

namespace CareSitter.ApiHost.Security;

/// <summary>
/// Lay user tu JWT claims cua request. Cung cap UserId de DbContext set GUC app.current_user_id (RLS).
/// MVP: doc claim "sub" + "role"; noi JWT auth o buoc Identity.
/// </summary>
internal sealed class HttpContextCurrentUser : ICurrentUser
{
    private readonly IHttpContextAccessor _accessor;

    public HttpContextCurrentUser(IHttpContextAccessor accessor) => _accessor = accessor;

    public Guid? UserId
    {
        get
        {
            var sub = _accessor.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier)
                      ?? _accessor.HttpContext?.User.FindFirstValue("sub");
            return Guid.TryParse(sub, out var id) ? id : null;
        }
    }

    public IReadOnlyCollection<string> Roles =>
        _accessor.HttpContext?.User.FindAll(ClaimTypes.Role).Select(c => c.Value).ToArray()
        ?? Array.Empty<string>();

    public bool IsInRole(string role) => Roles.Contains(role);
}
