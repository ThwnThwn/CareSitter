namespace CareSitter.ApiHost.Matching;

public sealed class MatchingOptions
{
    public int InitialOfferCount { get; set; } = 3;
    public int ExpansionOfferCount { get; set; } = 3;
    public int OfferLifetimeMinutes { get; set; } = 10;
    public int MaxDistanceMeters { get; set; } = 10000;
    public decimal MinimumRating { get; set; } = 3.5m;
    public bool AllowCaregiversWithoutAvailabilitySlots { get; set; } = true;
    public MatchingWeights Weights { get; set; } = new();
}

public sealed class MatchingWeights
{
    public decimal Distance { get; set; } = 0.35m;
    public decimal Rating { get; set; } = 0.30m;
    public decimal SkillMatch { get; set; } = 0.25m;
    public decimal Experience { get; set; } = 0.10m;
}
