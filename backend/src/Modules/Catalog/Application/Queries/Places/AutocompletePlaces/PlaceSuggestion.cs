namespace CareSitter.Modules.Catalog.Application;

public sealed record PlaceSuggestion(
    string PlaceId,
    string Description,
    string MainText,
    string SecondaryText);
