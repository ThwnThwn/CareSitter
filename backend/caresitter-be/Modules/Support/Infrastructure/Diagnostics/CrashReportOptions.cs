using System.Text.RegularExpressions;

namespace CareSitter.Modules.Support.Infrastructure.Diagnostics;

public sealed class CrashReportOptions
{
    public bool Enabled { get; set; }
    public string ProjectId { get; set; } = "";
    public string Dataset { get; set; } = "firebase_crashlytics";
    public string Table { get; set; } = "vn_caresitter_customer_IOS";
    public string Location { get; set; } = "US";
    public string ServiceAccountPath { get; set; } = "";
    public long MaximumBytesBilled { get; set; } = 100_000_000;
    public bool IsValid => !Enabled ||
        (Regex.IsMatch(ProjectId, "^[a-z][a-z0-9-]{4,61}[a-z0-9]$") &&
         Dataset == "firebase_crashlytics" &&
         Regex.IsMatch(Table, "^vn_caresitter_(customer|caregiver)_(ANDROID|IOS)(_REALTIME)?$") &&
         Regex.IsMatch(Location, "^[A-Za-z0-9-]{2,32}$") &&
         MaximumBytesBilled is >= 10_000_000 and <= 1_000_000_000);
}
