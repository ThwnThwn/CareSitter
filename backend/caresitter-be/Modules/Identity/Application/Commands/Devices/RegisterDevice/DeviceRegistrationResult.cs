using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application;

public sealed record DeviceRegistrationResult(DeviceResponse Device, bool Created);
