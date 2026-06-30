using CareSitter.Infrastructure.Persistence;
using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Booking.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Infrastructure;

/// <summary>DbContext module Booking — map vao schema "booking".</summary>
public sealed class BookingDbContext : ModuleDbContext
{
    public const string SchemaName = "booking";

    public BookingDbContext(DbContextOptions<BookingDbContext> options, ICurrentUser? currentUser = null)
        : base(options, currentUser) { }

    protected override string Schema => SchemaName;

    public DbSet<Domain.Booking> Bookings => Set<Domain.Booking>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Domain.Booking>(b =>
        {
            b.ToTable("bookings");
            b.HasKey(x => x.Id);
            b.Property(x => x.Status)
                .HasConversion<string>()
                .HasMaxLength(50);
            b.Property(x => x.EscrowAmount);
            b.Property(x => x.PlatformFeeAmount);
            b.Property(x => x.CaregiverEarningAmount);
            b.Property(x => x.GeofenceRadiusMeters);
            b.Ignore(x => x.DomainEvents);
        });
    }
}
