using CareSitter.Modules.Support.Application;
using CareSitter.Modules.Support.Application.Commands.CreateReview;

namespace CareSitter.Modules.Support.Controllers;

public sealed record CreateReviewRequest(Guid BookingId, Guid CaregiverId, int Rating,
    string? Comment = null, string? ExperienceTags = null);
