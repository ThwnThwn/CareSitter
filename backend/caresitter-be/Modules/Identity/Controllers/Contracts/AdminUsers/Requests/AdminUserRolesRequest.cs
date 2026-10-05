using CareSitter.Modules.Identity.Application;

namespace CareSitter.Modules.Identity.Controllers;

public sealed record AdminUserRolesRequest(string[]? Roles);
