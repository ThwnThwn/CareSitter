using CareSitter.Modules.Booking.Domain;
using Xunit;

namespace CareSitter.Modules.Booking.UnitTests;

public class CareTaskDomainTests
{
    [Fact]
    public void Create_ShouldInitializePendingTask()
    {
        // Arrange
        var bookingId = Guid.NewGuid();

        // Act
        var task = CareTask.Create(bookingId, "Do Huyet Ap", "Do huyet ap va ghi nhan", isRequired: true, requiresPhoto: false, sortOrder: 1);

        // Assert
        Assert.NotEqual(Guid.Empty, task.Id);
        Assert.Equal(bookingId, task.BookingId);
        Assert.Equal("Do Huyet Ap", task.Name);
        Assert.Equal("PENDING", task.Status);
        Assert.True(task.IsRequired);
        Assert.Null(task.CompletedAt);
    }

    [Fact]
    public void MarkCompleted_ShouldUpdateStatusAndCompletedAt()
    {
        // Arrange
        var task = CareTask.Create(Guid.NewGuid(), "Uong Thuoc");

        // Act
        task.MarkCompleted(Guid.NewGuid());

        // Assert
        Assert.Equal("COMPLETED", task.Status);
        Assert.NotNull(task.CompletedAt);
    }

    [Fact]
    public void Skip_ShouldUpdateStatusToSkipped()
    {
        // Arrange
        var task = CareTask.Create(Guid.NewGuid(), "Tắm Rửa", isRequired: false);

        // Act
        task.Skip("Khách hàng không yêu cầu thực hiện");

        // Assert
        Assert.Equal("SKIPPED", task.Status);
    }
}
