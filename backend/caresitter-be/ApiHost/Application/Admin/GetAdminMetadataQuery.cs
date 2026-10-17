using CareSitter.Contracts.Services;
using MediatR;

namespace CareSitter.ApiHost.Application.Admin;

// Tổng hợp dữ liệu qua các reader để controller chỉ nhận request và trả response.
public sealed record GetAdminMetadataQuery : IRequest<object?>;

public sealed class GetAdminMetadataQueryHandler(
    IAdminIdentityReader identityReader,
    IAdminBookingReader bookingReader,
    IAdminSupportReader supportReader,
    ICurrentUser currentUser) : IRequestHandler<GetAdminMetadataQuery, object?>
{
    public async Task<object?> Handle(GetAdminMetadataQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return null;

        var user = await identityReader.FindUserAsync(userId, ct);
        if (user is null) return null;

        var bookingStatuses = bookingReader.GetStatusDescriptors()
            .Select(x => new AdminOption(x.Value, x.Label, x.Tone))
            .ToArray();

        var kycStatuses = new[]
        {
            Option("PENDING", "Chờ duyệt", "warning"),
            Option("APPROVED", "Đã duyệt", "success"),
            Option("REJECTED", "Đã từ chối", "danger"),
            Option("DRAFT", "Bản nháp", "neutral")
        };
        var payoutStatuses = new[]
        {
            Option("PENDING", "Chờ duyệt", "warning"),
            Option("APPROVED", "Đã duyệt, chờ payOS", "info"),
            Option("REJECTED", "Đã từ chối", "danger"),
            Option("PROCESSING", "Đang chuyển", "info"),
            Option("PAID", "Đã trả", "success"),
            Option("FAILED", "Thất bại", "danger")
        };
        var ticketStatuses = new[]
        {
            Option("NEW", "Mới", "warning"),
            Option("IN_PROGRESS", "Đang xử lý", "info"),
            Option("RESOLVED", "Đã giải quyết", "success"),
            Option("CLOSED", "Đã đóng", "neutral")
        };
        var disputeStatuses = new[]
        {
            Option("OPEN", "Đang mở", "warning"),
            Option("INVESTIGATING", "Đang xác minh", "info"),
            Option("RESOLVED", "Đã giải quyết", "success"),
            Option("CANCELLED", "Đã hủy", "danger")
        };
        var userStatuses = new[]
        {
            Option("ACTIVE", "Đang hoạt động", "success", actionLabel: "Mở lại tài khoản"),
            Option("SUSPENDED", "Tạm ngưng", "neutral", actionLabel: "Tạm ngưng"),
            Option("LOCKED", "Đã khóa", "danger", actionLabel: "Khóa tài khoản")
        };
        var roles = new[]
        {
            Option("CUSTOMER", "Customer", "neutral", "Đặt và quản lý booking"),
            Option("CAREGIVER", "Caregiver", "neutral", "Nhận và thực hiện ca chăm sóc"),
            Option("ADMIN", "Admin", "info", "Truy cập operations console")
        };
        var ticketTypes = new[]
        {
            Option("COMPLAINT", "Phản ánh"),
            Option("SOS", "SOS", "danger"),
            Option("PAYMENT", "Thanh toán"),
            Option("KYC", "KYC"),
            Option("CHECKOUT_REVIEW", "Checkout"),
            Option("GENERAL", "Khác")
        };
        var ticketPriorities = new[]
        {
            Option("CRITICAL", "Khẩn cấp", "danger"),
            Option("HIGH", "Cao", "warning"),
            Option("MEDIUM", "Trung bình", "neutral"),
            Option("LOW", "Thấp", "neutral")
        };
        var disputeDecisions = new[]
        {
            Option("CUSTOMER_WINS", "Khách hàng thắng"),
            Option("CAREGIVER_WINS", "Caregiver thắng"),
            Option("PARTIAL_REFUND", "Hoàn tiền một phần")
        };

        var statusDefinitions = bookingStatuses
            .Concat(kycStatuses)
            .Concat(payoutStatuses)
            .Concat(ticketStatuses)
            .Concat(disputeStatuses)
            .Concat(userStatuses)
            .Concat(roles)
            .Concat(ticketTypes)
            .Concat(ticketPriorities)
            .Concat(disputeDecisions)
            .Concat(new[]
            {
                Option("NEEDS_REVIEW", "Cần đối soát", "warning"),
                Option("SKIPPED", "Đã bỏ qua", "neutral"),
                Option("PAYMENT", "Thanh toán", "neutral"),
                Option("KYC", "KYC", "neutral"),
                Option("PAYOUT", "Rút tiền", "neutral"),
                Option("SUPPORT", "Hỗ trợ", "neutral"),
                Option("DISPUTE", "Khiếu nại", "neutral"),
                Option("INACTIVE", "Đã tắt", "neutral"),
                Option("SCHEDULED", "Sắp diễn ra", "info"),
                Option("EXPIRED", "Đã hết hạn", "neutral")
            })
            .GroupBy(x => x.Value, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(x => x.Key, x => new { x.First().Label, x.First().Tone }, StringComparer.OrdinalIgnoreCase);

        return new
        {
            schemaVersion = 1,
            currentUser = new
            {
                user.Id,
                user.Email,
                displayName = user.DisplayName ?? user.FullName ?? user.Email,
                user.Roles,
                department = user.Department
            },
            navigation = new[]
            {
                new AdminNavigation("dashboard", "Tổng quan", []),
                new AdminNavigation("bookings", "Booking", []),
                new AdminNavigation("kyc", "Nhân sự & KYC", ["KYC"]),
                new AdminNavigation("payments", "Thanh toán", ["PAYMENT", "PAYOUT"]),
                new AdminNavigation("support", "Hỗ trợ", ["SUPPORT"]),
                new AdminNavigation("disputes", "Khiếu nại", ["DISPUTE"]),
                new AdminNavigation("services", "Dịch vụ", []),
                new AdminNavigation("promotions", "Ưu đãi", []),
                new AdminNavigation("users", "Tài khoản", [])
            },
            statusDefinitions,
            filters = new
            {
                bookings = Filter(string.Empty, AllOption("Tất cả trạng thái").Concat(bookingStatuses).ToArray()),
                kyc = Filter("PENDING", kycStatuses.Concat([Option("ALL", "Tất cả")]).ToArray()),
                payouts = Filter("PENDING", payoutStatuses.Concat([Option("ALL", "Tất cả")]).ToArray()),
                tickets = Filter(string.Empty, AllOption("Tất cả").Concat(ticketStatuses).ToArray()),
                ticketTypes = Filter(string.Empty, AllOption("Tất cả").Concat(ticketTypes).ToArray()),
                ticketPriorities = Filter(string.Empty, AllOption("Tất cả").Concat(ticketPriorities).ToArray()),
                disputes = Filter(string.Empty, AllOption("Tất cả").Concat(disputeStatuses).ToArray()),
                userRoles = Filter(string.Empty, AllOption("Tất cả").Concat(roles).ToArray()),
                userStatuses = Filter(string.Empty, AllOption("Tất cả").Concat(userStatuses).ToArray())
            },
            roles,
            userStatuses,
            disputeDecisions,
            transitions = new
            {
                support = supportReader.GetTicketTransitions()
            },
            reviewableStatuses = new
            {
                kyc = new[] { "PENDING" },
                payouts = new[] { "PENDING" },
                disputes = new[] { "OPEN", "INVESTIGATING" }
            },
            dashboard = new
            {
                metricCards = new[]
                {
                    new AdminMetric("bookingsToday", "Booking hôm nay", "Theo lịch bắt đầu", "bookings"),
                    new AdminMetric("pendingKyc", "KYC chờ duyệt", "Cần kiểm tra giấy tờ", "kyc"),
                    new AdminMetric("pendingPayouts", "Rút tiền chờ duyệt", "Cần đối chiếu ngân hàng", "payments"),
                    new AdminMetric("openTickets", "Ticket đang mở", "Mới hoặc đang xử lý", "support")
                }
            },
            defaults = new
            {
                service = new { defaultDurationMinutes = 60, isActive = true },
                pricingRule = new
                {
                    name = "Bảng giá tiêu chuẩn",
                    baseHourlyPrice = 0L,
                    nightMultiplier = 1.00m,
                    holidayMultiplier = 1.00m,
                    platformFeePercent = 15.00m,
                    disputeWindowHours = 48,
                    isActive = true
                },
                checklist = new { isRequired = true, requiresPhoto = false, firstSortOrder = 1 }
            },
            constraints = new
            {
                serviceDurationMinutes = new { min = 15, max = 1440 },
                priceMultiplier = new { min = 1, max = 10, step = 0.1m },
                platformFeePercent = new { min = 0, max = 100, step = 0.1m },
                disputeWindowHours = new { min = 1, max = 720 },
                rejectionReasonMinLength = 5
            }
        };
    }

    private static AdminFilter Filter(string defaultValue, AdminOption[] options) => new(defaultValue, options);
    private static IEnumerable<AdminOption> AllOption(string label) => [Option(string.Empty, label)];
    private static AdminOption Option(string value, string label, string tone = "neutral",
        string? description = null, string? actionLabel = null) =>
        new(value, label, tone, description, actionLabel);

}

public sealed record AdminOption(
    string Value,
    string Label,
    string Tone = "neutral",
    string? Description = null,
    string? ActionLabel = null);

public sealed record AdminFilter(string DefaultValue, AdminOption[] Options);
public sealed record AdminNavigation(string Key, string Label, string[] WorkTypes);
public sealed record AdminMetric(string Key, string Label, string Note, string Page);
