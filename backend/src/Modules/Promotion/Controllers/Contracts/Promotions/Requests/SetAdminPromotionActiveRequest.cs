namespace CareSitter.Modules.Promotion.Controllers;

public sealed record SetAdminPromotionActiveRequest(bool IsActive, DateTimeOffset ExpectedUpdatedAt);
