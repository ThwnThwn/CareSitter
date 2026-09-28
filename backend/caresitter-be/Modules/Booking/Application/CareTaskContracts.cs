using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record CareTaskResponse(
    Guid Id, Guid BookingId, string Name, string? Description,
    bool IsRequired, bool RequiresPhoto, int SortOrder, string Status,
    DateTimeOffset? CompletedAt, string[] PhotoUrls, string Source,
    string? SkipReason, Guid? CompletedBy, DateTimeOffset CreatedAt);
public sealed record CareTaskPhotoResponse(
    Guid TaskId, Guid MediaId, string Url, DateTimeOffset UploadedAt);

public sealed record ListCareTasksQuery(Guid BookingId)
    : IRequest<Result<IReadOnlyList<CareTaskResponse>>>;
public sealed record CreateCareTaskCommand(
    Guid BookingId, string Name, string? Description)
    : IRequest<Result<CareTaskResponse>>;
public sealed record CompleteCareTaskCommand(Guid BookingId, Guid TaskId)
    : IRequest<Result<CareTaskResponse>>;
public sealed record UploadCareTaskPhotoCommand(
    Guid BookingId, Guid TaskId, Stream Content, string FileName,
    string ContentType, long Length) : IRequest<Result<CareTaskPhotoResponse>>;
public sealed record SkipCareTaskCommand(Guid BookingId, Guid TaskId, string SkipReason)
    : IRequest<Result<CareTaskResponse>>;

internal interface ICareTaskManager
{
    Task<Result<IReadOnlyList<CareTaskResponse>>> ListAsync(
        Guid bookingId, CancellationToken ct = default);
    Task<Result<CareTaskResponse>> CreateAsync(
        Guid bookingId, string name, string? description, CancellationToken ct = default);
    Task<Result<CareTaskResponse>> CompleteAsync(
        Guid bookingId, Guid taskId, CancellationToken ct = default);
    Task<Result<CareTaskPhotoResponse>> UploadPhotoAsync(
        UploadCareTaskPhotoCommand request, CancellationToken ct = default);
    Task<Result<CareTaskResponse>> SkipAsync(
        Guid bookingId, Guid taskId, string reason, CancellationToken ct = default);
}

internal sealed class CareTaskHandlers(ICareTaskManager manager) :
    IRequestHandler<ListCareTasksQuery, Result<IReadOnlyList<CareTaskResponse>>>,
    IRequestHandler<CreateCareTaskCommand, Result<CareTaskResponse>>,
    IRequestHandler<CompleteCareTaskCommand, Result<CareTaskResponse>>,
    IRequestHandler<UploadCareTaskPhotoCommand, Result<CareTaskPhotoResponse>>,
    IRequestHandler<SkipCareTaskCommand, Result<CareTaskResponse>>
{
    public Task<Result<IReadOnlyList<CareTaskResponse>>> Handle(
        ListCareTasksQuery request, CancellationToken ct) =>
        manager.ListAsync(request.BookingId, ct);
    public Task<Result<CareTaskResponse>> Handle(
        CreateCareTaskCommand request, CancellationToken ct) =>
        manager.CreateAsync(request.BookingId, request.Name, request.Description, ct);
    public Task<Result<CareTaskResponse>> Handle(
        CompleteCareTaskCommand request, CancellationToken ct) =>
        manager.CompleteAsync(request.BookingId, request.TaskId, ct);
    public Task<Result<CareTaskPhotoResponse>> Handle(
        UploadCareTaskPhotoCommand request, CancellationToken ct) =>
        manager.UploadPhotoAsync(request, ct);
    public Task<Result<CareTaskResponse>> Handle(
        SkipCareTaskCommand request, CancellationToken ct) =>
        manager.SkipAsync(request.BookingId, request.TaskId, request.SkipReason, ct);
}
