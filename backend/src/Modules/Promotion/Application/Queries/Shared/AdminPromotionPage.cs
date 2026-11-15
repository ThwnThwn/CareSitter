namespace CareSitter.Modules.Promotion.Application;

public sealed record AdminPromotionPage(IReadOnlyList<AdminPromotionResponse> Items, int Total, int Page, int PageSize);
