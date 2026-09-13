namespace CareSitter.Modules.Booking.Application;

/// <summary>Chinh sach check-in toan cuc, bind tu section <c>CheckIn</c>.</summary>
public sealed class CheckInOptions
{
    public const string SectionName = "CheckIn";

    /// <summary>So phut som nhat caregiver duoc check-in truoc gio bat dau ca.</summary>
    public int EarlyWindowMinutes { get; init; } = 30;

    /// <summary>Khoang cach GPS toi da tinh tu dia chi cham soc.</summary>
    public int MaxDistanceMeters { get; init; } = 50;
}
