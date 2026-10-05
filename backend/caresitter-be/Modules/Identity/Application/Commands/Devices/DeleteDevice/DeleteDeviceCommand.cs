using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

public sealed record DeleteDeviceCommand(Guid DeviceId) : IRequest<Result>;
