using System.Text.Json;
using CareSitter.Contracts.Nutrition;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal sealed class BookingMealHandlers(IBookingMealStore store, IBookingReadStore bookings,
    IMealPlanSnapshotReader nutrition, ICurrentUser user, IPeopleLookupService people, IClock clock, IBeneficiaryHealthSnapshotReader health)
    : IRequestHandler<ShareBookingMealPlanCommand, Result<BookingMealPlanResponse>>,
      IRequestHandler<RevokeBookingMealPlanCommand, Result<bool>>,
      IRequestHandler<ListBookingMealsQuery, Result<BookingMealsResponse>>,
      IRequestHandler<RecordBookingMealCommand, Result<BookingMealRecordResponse>>
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    public async Task<Result<BookingMealPlanResponse>> Handle(ShareBookingMealPlanCommand request, CancellationToken ct)
    {
        if (user.UserId is not { } userId) return BookingErrors.Unauthenticated();
        var booking = await bookings.GetAsync(request.BookingId, ct);
        if (booking is null) return BookingErrors.NotFound();
        if (booking.CustomerId != userId) return BookingErrors.Forbidden();
        if (request.PlanId == Guid.Empty) return Invalid("Thực đơn không hợp lệ.");
        var snapshot = await nutrition.ReadAsync(booking.BeneficiaryId, request.PlanId, ct);
        if (snapshot.IsFailure) return snapshot.Error;
        var plan = snapshot.Value;
        if (plan.Id != request.PlanId || plan.BeneficiaryId != booking.BeneficiaryId)
            return BookingErrors.Forbidden();
        return await store.InBookingScopeAsync<BookingMealPlanResponse>(booking.Id, async (current, session) =>
        {
            if (current.CustomerId != userId || current.BeneficiaryId != plan.BeneficiaryId)
                return BookingErrors.Forbidden();
            if (!BookingMealPolicy.CanShare(current.Status) || !BookingMealPolicy.CoversDate(current, plan.PlannedDate))
                return Invalid("Ngày thực đơn phải thuộc ca chăm sóc còn hiệu lực.");
            var revision = await health.ReadAsync(current.CustomerId, current.BeneficiaryId, ct);
            if (plan.HealthRevision < 1 || revision?.Revision != plan.HealthRevision)
                return Stale();
            var existing = (await session.PlansAsync(ct)).SingleOrDefault(x => x.PlannedDate == plan.PlannedDate);
            var mealsJson = JsonSerializer.Serialize(plan.Meals, Json);
            if (existing is not null)
            {
                if (existing.PlanId != plan.Id && (await session.RecordsAsync(ct)).Any(x => x.PlannedDate == plan.PlannedDate))
                    return Error.Conflict("booking.meals.already_recorded", "Bữa ăn đã có ghi nhận; không thể thay thực đơn của ngày này.");
                if (existing.PlanId == plan.Id && existing.HealthRevision == plan.HealthRevision && existing.RevokedAt is null &&
                    existing.HealthFingerprint == MealHealthFingerprint.For(revision!)) return Map(existing);
                existing.Reshare(plan.Id, mealsJson, userId, clock.UtcNow, plan.HealthRevision, MealHealthFingerprint.For(revision!));
                return Map(existing);
            }
            var linked = BookingMealPlan.Share(current.Id, plan.Id, plan.PlannedDate, mealsJson, userId, clock.UtcNow, plan.HealthRevision, MealHealthFingerprint.For(revision!));
            session.Add(linked);
            return Map(linked);
        }, ct);
    }

    public async Task<Result<bool>> Handle(RevokeBookingMealPlanCommand request, CancellationToken ct)
    {
        if (user.UserId is not { } userId) return BookingErrors.Unauthenticated();
        return await store.InBookingScopeAsync<bool>(request.BookingId, async (booking, session) =>
        {
            if (booking.CustomerId != userId) return BookingErrors.Forbidden();
            var plan = (await session.PlansAsync(ct)).SingleOrDefault(x => x.PlannedDate == request.PlannedDate);
            plan?.Revoke(clock.UtcNow);
            return true;
        }, ct);
    }

    public async Task<Result<BookingMealsResponse>> Handle(ListBookingMealsQuery request, CancellationToken ct)
    {
        if (user.UserId is not { } actor) return BookingErrors.Unauthenticated();
        return await store.InBookingScopeAsync<BookingMealsResponse>(request.BookingId, async (booking, session) =>
        {
            var owner = actor == booking.CustomerId;
            if (!owner && !await AssignedCaregiverAsync(booking, ct)) return BookingErrors.Forbidden();
            if (!owner && !BookingMealPolicy.CanCaregiverRead(booking.Status)) return BookingErrors.Forbidden();
            var plans = (await session.PlansAsync(ct)).Where(x => owner ||
                (x.RevokedAt is null && BookingMealPolicy.CoversDate(booking, x.PlannedDate))).ToArray();
            var visiblePlanIds = plans.Select(x => x.PlanId).ToHashSet();
            var records = (await session.RecordsAsync(ct)).Where(x => owner || visiblePlanIds.Contains(x.PlanId));
            var revision = plans.Length == 0 ? null : await health.ReadAsync(booking.CustomerId, booking.BeneficiaryId, ct);
            var today = BookingMealPolicy.VietnamDate(clock.UtcNow);
            var canRecord = !owner && BookingMealPolicy.CanRecord(booking);
            var canCorrect = !owner && BookingMealPolicy.CanCorrect(booking.Status);
            var view = plans.Select(plan =>
            {
                var stale = !MealHealthFingerprint.Current(plan, revision);
                return new BookingMealPlanResponse(plan.PlanId, plan.PlannedDate,
                    !owner && stale ? [] : Meals(plan), plan.SharedAt, plan.RevokedAt, stale,
                    plan.RevokedAt is not null ? "revoked" : stale ? "stale" : "shared",
                    CanRecord: canRecord && !stale && plan.PlannedDate <= today);
            }).ToArray();
            var history = await session.CorrectionsAsync(ct);
            var shareWindow = owner && user.IsInRole("CUSTOMER") && BookingMealPolicy.CanShare(booking.Status)
                ? new BookingMealShareWindow(booking.BeneficiaryId, BookingMealPolicy.VietnamDate(booking.ScheduledStart),
                    BookingMealPolicy.LastDate(booking))
                : null;
            return new BookingMealsResponse(view, records.Select(record =>
                BookingMealRecordMapping.Map(record, history) with
                {
                    CanCorrect = canCorrect && record.RecordedBy == actor
                }).ToArray(), shareWindow);
        }, ct);
    }

    public async Task<Result<BookingMealRecordResponse>> Handle(RecordBookingMealCommand request, CancellationToken ct)
    {
        if (user.UserId is not { } userId) return BookingErrors.Unauthenticated();
        if (request.IdempotencyKey == Guid.Empty || request.PlanId == Guid.Empty || request.RecipeVersionId == Guid.Empty ||
            request.MealType is not ("breakfast" or "lunch" or "dinner") ||
            request.Outcome is not ("eaten" or "partly_eaten" or "not_eaten") || request.Note?.Length > 1000)
            return Invalid("Thông tin ghi nhận bữa ăn không hợp lệ.");
        return await store.InBookingScopeAsync<BookingMealRecordResponse>(request.BookingId, async (booking, session) =>
        {
            if (!await AssignedCaregiverAsync(booking, ct)) return BookingErrors.Forbidden();
            if (!BookingMealPolicy.CanCaregiverRead(booking.Status)) return BookingErrors.Forbidden();
            var plan = (await session.PlansAsync(ct)).SingleOrDefault(x => x.PlanId == request.PlanId && x.RevokedAt is null);
            if (plan is null || !BookingMealPolicy.CoversDate(booking, plan.PlannedDate) ||
                plan.PlannedDate > BookingMealPolicy.VietnamDate(clock.UtcNow))
                return Invalid("Thực đơn chưa được chia sẻ cho ngày chăm sóc này.");
            var revision = await health.ReadAsync(booking.CustomerId, booking.BeneficiaryId, ct);
            if (!MealHealthFingerprint.Current(plan, revision)) return Stale();
            var records = await session.RecordsAsync(ct);
            var previous = records.SingleOrDefault(x => x.IdempotencyKey == request.IdempotencyKey);
            var note = string.IsNullOrWhiteSpace(request.Note) ? null : request.Note.Trim();
            if (previous is not null)
                return previous.RecordedBy == userId && previous.PlanId == request.PlanId &&
                    previous.RecipeVersionId == request.RecipeVersionId && previous.MealType == request.MealType &&
                    previous.Outcome == request.Outcome && previous.Note == note
                        ? Map(previous) : Error.Conflict("booking.meals.idempotency_conflict", "Khóa ghi nhận đã được dùng cho nội dung khác.");
            if (!BookingMealPolicy.CanRecord(booking))
                return Error.Conflict("booking.meals.shift_not_active", "Chỉ ghi nhận bữa ăn trong ca đã bắt đầu.");
            var meal = Meals(plan).SingleOrDefault(x => x.VersionId == request.RecipeVersionId && x.MealType == request.MealType);
            if (meal is null) return Invalid("Món ăn không thuộc thực đơn đã chia sẻ.");
            if (records.Any(x => x.PlannedDate == plan.PlannedDate && x.MealType == request.MealType))
                return Error.Conflict("booking.meals.already_recorded", "Bữa ăn này đã được ghi nhận. Vui lòng tải lại nhật ký.");
            var label = request.Outcome switch { "eaten" => "Đã ăn", "partly_eaten" => "Ăn một phần", _ => "Không ăn" };
            var title = $"{label}: {meal.Name}";
            if (title.Length > 255) title = title[..255];
            var timeline = CareTimelineEvent.Create(booking.Id, booking.CaregiverId, "NOTE", title,
                note, metadata: JsonSerializer.Serialize(new { kind = "meal_record", planId = plan.PlanId,
                    plannedDate = plan.PlannedDate, recipeVersionId = meal.VersionId, request.MealType, request.Outcome }, Json));
            var record = BookingMealRecord.Create(booking.Id, plan.PlanId, plan.PlannedDate, meal.VersionId,
                request.MealType, request.Outcome, note, userId, clock.UtcNow, request.IdempotencyKey, timeline.Id);
            session.Add(record, timeline);
            return Map(record);
        }, ct);
    }

    private async Task<bool> AssignedCaregiverAsync(Domain.Booking booking, CancellationToken ct) =>
        user.IsInRole("CAREGIVER") && booking.CaregiverId is { } id &&
        await people.IsCaregiverForBookingAsync(id, user.UserId!.Value, ct);
    private static SharedMeal[] Meals(BookingMealPlan plan) =>
        JsonSerializer.Deserialize<SharedMeal[]>(plan.MealsJson, Json) ?? [];
    private static BookingMealPlanResponse Map(BookingMealPlan plan) =>
        new(plan.PlanId, plan.PlannedDate, Meals(plan), plan.SharedAt, plan.RevokedAt);
    private static BookingMealRecordResponse Map(BookingMealRecord record) =>
        new(record.Id, record.PlanId, record.PlannedDate, record.RecipeVersionId, record.MealType,
            record.Outcome, record.Note, record.RecordedBy, record.RecordedAt, record.TimelineEventId);
    private static Error Stale() => Error.Conflict("booking.meals.plan_stale",
        "Thông tin hồ sơ đã thay đổi. Gia đình cần kiểm tra và chia sẻ lại thực đơn trước khi tiếp tục ghi nhận bữa ăn.");
    private static Error Invalid(string message) => Error.Validation("booking.meals.request", message);
}
