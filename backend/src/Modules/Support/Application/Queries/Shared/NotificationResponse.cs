namespace CareSitter.Modules.Support.Application;

public sealed record NotificationResponse(Guid Id, string Type, string Title,
    string? Body, string? Data, DateTimeOffset? ReadAt, DateTimeOffset CreatedAt);
