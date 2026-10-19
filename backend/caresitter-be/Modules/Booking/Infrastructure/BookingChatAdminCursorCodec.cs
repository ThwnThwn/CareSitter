using System.Text;

namespace CareSitter.Modules.Booking.Infrastructure;

internal static class BookingChatAdminCursorCodec
{
    public static string Encode(DateTimeOffset timestamp, Guid id) =>
        Convert.ToBase64String(Encoding.UTF8.GetBytes($"{timestamp:O}|{id:D}"));

    public static bool TryDecode(string? cursor, out DateTimeOffset timestamp, out Guid id)
    {
        timestamp = default;
        id = default;
        if (string.IsNullOrWhiteSpace(cursor)) return false;
        try
        {
            var value = Encoding.UTF8.GetString(Convert.FromBase64String(cursor));
            var separator = value.LastIndexOf('|');
            return separator > 0 &&
                DateTimeOffset.TryParseExact(value[..separator], "O", null,
                    System.Globalization.DateTimeStyles.RoundtripKind, out timestamp) &&
                Guid.TryParse(value[(separator + 1)..], out id);
        }
        catch (FormatException)
        {
            return false;
        }
    }
}
