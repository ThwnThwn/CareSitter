using CareSitter.Modules.Identity.Application.Profile.Dtos.Requests;
using CareSitter.Modules.Identity.Application.UpdateProfile;

namespace CareSitter.Modules.Identity.Application.Profile.Mapping;

public static class ProfileRequestMapper
{
    public static UpdateProfileCommand ToCommand(this UpdateProfileRequest request) =>
        new(request.FullName, request.Email, request.DisplayName, request.DateOfBirth, request.Gender);
}
