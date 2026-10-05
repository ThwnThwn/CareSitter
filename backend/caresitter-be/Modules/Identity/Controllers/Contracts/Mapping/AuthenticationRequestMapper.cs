using CareSitter.Modules.Identity.Application.Authentication.Dtos.Requests;
using CareSitter.Modules.Identity.Application.Login;
using CareSitter.Modules.Identity.Application.LoginWithPassword;
using CareSitter.Modules.Identity.Application.RefreshToken;
using CareSitter.Modules.Identity.Application.Register;
using CareSitter.Modules.Identity.Application.SendOtp;

namespace CareSitter.Modules.Identity.Application.Authentication.Mapping;

public static class AuthenticationRequestMapper
{
    public static SendOtpCommand ToCommand(this SendOtpRequest request) => new(request.Email);
    public static LoginCommand ToCommand(this LoginRequest request) =>
        new(request.Email, request.Otp, request.RequiredRole);
    public static LoginWithPasswordCommand ToCommand(this LoginWithPasswordRequest request) =>
        new(request.Email, request.Password, request.RequiredRole);
    public static RegisterCommand ToCommand(this RegisterRequest request) =>
        new(request.Email, request.FullName, request.Roles,
            request.Password, request.ConfirmPassword, request.Phone);
    public static RefreshTokenCommand ToCommand(this RefreshTokenRequest request) =>
        new(request.RefreshToken);
}
