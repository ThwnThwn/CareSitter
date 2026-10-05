using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

public sealed record RegisterDeviceCommand(
    string Platform, string? PushToken = null, string? DeviceName = null)
    : IRequest<Result<DeviceRegistrationResult>>;
