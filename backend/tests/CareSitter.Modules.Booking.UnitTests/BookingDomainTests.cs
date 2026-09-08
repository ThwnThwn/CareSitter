using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.ValueObjects;
using Xunit;

namespace CareSitter.Modules.Booking.UnitTests;

public class BookingDomainTests
{
    [Fact]
    public void Create_WithValidSchedule_ShouldReturnSuccess()
    {
        // Arrange
        var customerId = Guid.NewGuid();
        var beneficiaryId = Guid.NewGuid();
        var addressId = Guid.NewGuid();
        var serviceTypeId = Guid.NewGuid();
        var start = DateTimeOffset.UtcNow.AddHours(2);
        var end = start.AddHours(4);

        // Act
        var result = Domain.Booking.Create(customerId, beneficiaryId, addressId, serviceTypeId, start, end, geofenceRadiusMeters: 50);

        // Assert
        Assert.True(result.IsSuccess);
        var booking = result.Value;
        Assert.Equal(customerId, booking.CustomerId);
        Assert.Equal(beneficiaryId, booking.BeneficiaryId);
        Assert.Equal(addressId, booking.AddressId);
        Assert.Equal(serviceTypeId, booking.ServiceTypeId);
        Assert.Equal(BookingStatus.Draft, booking.Status);
        Assert.Equal(50, booking.GeofenceRadiusMeters);
    }

    [Fact]
    public void Create_WithInvalidSchedule_ShouldReturnFailure()
    {
        // Arrange
        var customerId = Guid.NewGuid();
        var beneficiaryId = Guid.NewGuid();
        var addressId = Guid.NewGuid();
        var serviceTypeId = Guid.NewGuid();
        var start = DateTimeOffset.UtcNow.AddHours(4);
        var end = start.AddHours(-2); // end before start

        // Act
        var result = Domain.Booking.Create(customerId, beneficiaryId, addressId, serviceTypeId, start, end);

        // Assert
        Assert.True(result.IsFailure);
        Assert.Equal("booking.schedule", result.Error.Code);
    }

    [Fact]
    public void ApplyPricing_WithValidAmounts_ShouldSetPricingProperties()
    {
        // Arrange
        var start = DateTimeOffset.UtcNow.AddHours(2);
        var end = start.AddHours(4);
        var booking = Domain.Booking.Create(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), start, end).Value;

        // Act
        var result = booking.ApplyPricing(escrow: 500000, platformFee: 50000, caregiverEarning: 450000, snapshot: "{\"rate\":125000}");

        // Assert
        Assert.True(result.IsSuccess);
        Assert.Equal(500000, booking.EscrowAmount);
        Assert.Equal(50000, booking.PlatformFeeAmount);
        Assert.Equal(450000, booking.CaregiverEarningAmount);
        Assert.Equal("{\"rate\":125000}", booking.PriceSnapshot);
    }

    [Fact]
    public void CheckIn_WithinGeofence_ShouldTransitionToInProgress()
    {
        // Arrange
        var start = DateTimeOffset.UtcNow.AddHours(2);
        var end = start.AddHours(4);
        var booking = Domain.Booking.Create(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), start, end, geofenceRadiusMeters: 100).Value;
        var caregiverId = Guid.NewGuid();

        // Advance booking status to CaregiverEnRoute
        booking.SelectCaregiver(caregiverId);
        booking.TransitionTo(BookingStatus.PendingPayment);
        booking.TransitionTo(BookingStatus.Confirmed);
        booking.AssignCaregiver(caregiverId); // -> CaregiverAccepted
        booking.StartEnRoute(); // -> CaregiverEnRoute

        // 10 meters distance
        var addressLocation = new GeoPoint(10.762622, 106.660172);
        var caregiverLocation = new GeoPoint(10.762630, 106.660180);

        // Act
        var result = booking.CheckIn(caregiverLocation, addressLocation);

        // Assert
        Assert.True(result.IsSuccess);
        Assert.Equal(BookingStatus.InProgress, booking.Status);
        Assert.NotNull(booking.ActualStart);
    }

    [Fact]
    public void CheckIn_OutsideGeofence_ShouldFailValidation()
    {
        // Arrange
        var start = DateTimeOffset.UtcNow.AddHours(2);
        var end = start.AddHours(4);
        var booking = Domain.Booking.Create(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), start, end, geofenceRadiusMeters: 50).Value;
        var caregiverId = Guid.NewGuid();

        booking.SelectCaregiver(caregiverId);
        booking.TransitionTo(BookingStatus.PendingPayment);
        booking.TransitionTo(BookingStatus.Confirmed);
        booking.AssignCaregiver(caregiverId);
        booking.StartEnRoute();

        // 10km distance away
        var addressLocation = new GeoPoint(10.762622, 106.660172);
        var caregiverLocation = new GeoPoint(10.850000, 106.750000);

        // Act
        var result = booking.CheckIn(caregiverLocation, addressLocation);

        // Assert
        Assert.True(result.IsFailure);
        Assert.Equal("booking.geofence", result.Error.Code);
        Assert.Equal(BookingStatus.CaregiverEnRoute, booking.Status);
    }

    [Fact]
    public void Complete_FromInProgress_ShouldTransitionToCompletedAndSetActualEnd()
    {
        // Arrange
        var start = DateTimeOffset.UtcNow.AddHours(2);
        var end = start.AddHours(4);
        var booking = Domain.Booking.Create(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), start, end).Value;
        var caregiverId = Guid.NewGuid();

        booking.SelectCaregiver(caregiverId);
        booking.TransitionTo(BookingStatus.PendingPayment);
        booking.TransitionTo(BookingStatus.Confirmed);
        booking.AssignCaregiver(caregiverId);
        booking.StartEnRoute();
        
        var location = new GeoPoint(10.762622, 106.660172);
        booking.CheckIn(location, location); // -> InProgress

        // Act
        var result = booking.Complete();

        // Assert
        Assert.True(result.IsSuccess);
        Assert.Equal(BookingStatus.Completed, booking.Status);
        Assert.NotNull(booking.ActualEnd);
    }
}
