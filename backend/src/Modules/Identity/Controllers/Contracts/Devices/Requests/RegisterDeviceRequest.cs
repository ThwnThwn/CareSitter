using CareSitter.Modules.Identity.Application;

namespace CareSitter.Modules.Identity.Controllers;

public sealed record RegisterDeviceRequest(
    string Platform, string? PushToken = null, string? DeviceName = null);
