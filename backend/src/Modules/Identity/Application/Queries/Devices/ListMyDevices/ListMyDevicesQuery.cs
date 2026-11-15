using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

public sealed record ListMyDevicesQuery : IRequest<Result<IReadOnlyList<DeviceResponse>>>;
