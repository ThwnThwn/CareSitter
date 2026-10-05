using CareSitter.Modules.Identity.Application;
using CareSitter.Modules.Identity.Application.UpdateProfile;

namespace CareSitter.Modules.Identity.Controllers;

public sealed record ChangePasswordRequest(string CurrentPassword, string NewPassword);
