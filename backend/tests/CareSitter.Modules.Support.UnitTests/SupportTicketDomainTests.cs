using CareSitter.Modules.Support.Domain;

namespace CareSitter.Modules.Support.UnitTests;

public sealed class SupportTicketDomainTests
{
    private static SupportTicket Ticket() => SupportTicket.Create(Guid.NewGuid(), " general ",
        title: " Cần hỗ trợ ", description: " Nội dung hỗ trợ đầy đủ ").Value;

    [Fact]
    public void Ticket_normalizes_input_and_assignment_starts_work()
    {
        var ticket = Ticket();
        Assert.Equal("GENERAL", ticket.Type);
        Assert.Equal("Cần hỗ trợ", ticket.Title);
        Assert.True(ticket.AssignAdmin(Guid.Empty).IsFailure);
        Assert.Equal("NEW", ticket.Status);
        var admin = Guid.NewGuid();
        Assert.True(ticket.AssignAdmin(admin).IsSuccess);
        Assert.Equal(admin, ticket.AssignedAdminId);
        Assert.Equal("IN_PROGRESS", ticket.Status);
    }

    [Fact]
    public void Ticket_can_resolve_then_close_but_cannot_reopen()
    {
        var ticket = Ticket();
        Assert.True(ticket.UpdateStatus("RESOLVED").IsFailure);
        Assert.True(ticket.UpdateStatus(" in_progress ").IsSuccess);
        Assert.True(ticket.UpdateStatus("RESOLVED").IsSuccess);
        Assert.True(ticket.UpdateStatus("CLOSED").IsSuccess);
        Assert.True(ticket.UpdateStatus("NEW").IsFailure);
        Assert.Equal("CLOSED", ticket.Status);
    }

    [Theory]
    [InlineData("UNKNOWN", "MEDIUM", "ticket.type")]
    [InlineData("GENERAL", "URGENT", "ticket.priority")]
    public void Unknown_type_or_priority_is_rejected(string type, string priority, string code)
        => Assert.Equal(code, SupportTicket.Create(Guid.NewGuid(), type, priority,
            title: "Valid title", description: "Valid description").Error.Code);

    [Fact]
    public void Too_short_description_is_rejected()
        => Assert.Equal("ticket.description", SupportTicket.Create(Guid.NewGuid(), "GENERAL",
            title: "Valid title", description: "short").Error.Code);
}
