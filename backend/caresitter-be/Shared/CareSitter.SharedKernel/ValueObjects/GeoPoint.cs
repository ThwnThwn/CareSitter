namespace CareSitter.SharedKernel.ValueObjects;

/// <summary>
/// Toa do WGS84 (SRID 4326). Map sang PostGIS geography(Point,4326) o tang Infrastructure.
/// </summary>
public readonly record struct GeoPoint(double Latitude, double Longitude)
{
    /// <summary>
    /// Khoang cach Haversine (met) — du cho geofence/matching o tang domain;
    /// truy van toi uu dung ST_DWithin tren PostGIS.
    /// </summary>
    public double DistanceMetersTo(GeoPoint other)
    {
        const double earthRadiusMeters = 6_371_000d;
        double dLat = DegToRad(other.Latitude - Latitude);
        double dLon = DegToRad(other.Longitude - Longitude);

        double a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2)
                   + Math.Cos(DegToRad(Latitude)) * Math.Cos(DegToRad(other.Latitude))
                   * Math.Sin(dLon / 2) * Math.Sin(dLon / 2);

        return earthRadiusMeters * 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
    }

    public bool IsWithin(GeoPoint center, double radiusMeters) => DistanceMetersTo(center) <= radiusMeters;

    private static double DegToRad(double deg) => deg * Math.PI / 180d;
}
