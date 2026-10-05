using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

public sealed record ChangePasswordCommand(string CurrentPassword, string NewPassword)
    : IRequest<Result<string>>;
