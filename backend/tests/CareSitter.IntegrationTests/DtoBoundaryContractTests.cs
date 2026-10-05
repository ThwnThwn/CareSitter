using System.Reflection;
using System.Text.Json;
using System.Text.Json.Nodes;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Bookings.Dtos.Requests;
using CareSitter.Modules.Booking.Application.Bookings.Mapping;
using CareSitter.Modules.Booking.Application.Commands.CreateBooking;
using CareSitter.Modules.Identity.Application.Authentication.Dtos.Requests;
using CareSitter.Modules.Identity.Application.Authentication.Mapping;
using CareSitter.Modules.Identity.Application.GoogleLogin;
using CareSitter.Modules.Identity.Application.Login;
using CareSitter.Modules.Identity.Application.LoginWithPassword;
using CareSitter.Modules.Identity.Application.Profile.Dtos.Requests;
using CareSitter.Modules.Identity.Application.Profile.Mapping;
using CareSitter.Modules.Identity.Application.RefreshToken;
using CareSitter.Modules.Identity.Application.Register;
using CareSitter.Modules.Identity.Application.SendOtp;
using CareSitter.Modules.Identity.Application.UpdateProfile;
using CareSitter.Modules.People.Controllers;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.IntegrationTests;

public sealed class DtoBoundaryContractTests
{
    private static readonly JsonSerializerOptions WebJson = new(JsonSerializerDefaults.Web);
    private static readonly Assembly[] ModuleAssemblies =
    [
        typeof(CareSitter.Modules.Identity.Controllers.AuthController).Assembly,
        typeof(CareSitter.Modules.Catalog.Controllers.AddressesController).Assembly,
        typeof(CareSitter.Modules.People.Controllers.CaregiverKycController).Assembly,
        typeof(CareSitter.Modules.Booking.Controllers.BookingsController).Assembly,
        typeof(CareSitter.Modules.Payments.Controllers.PaymentsController).Assembly,
        typeof(CareSitter.Modules.Promotion.Controllers.PromotionsController).Assembly,
        typeof(CareSitter.Modules.Support.Controllers.SupportTicketsController).Assembly
    ];

    [Fact]
    public void Every_controller_body_uses_a_dto_and_not_a_mediator_request()
    {
        var parameters = ModuleAssemblies.SelectMany(assembly => assembly.GetTypes())
            .Where(type => typeof(ControllerBase).IsAssignableFrom(type))
            .SelectMany(type => type.GetMethods(BindingFlags.Public | BindingFlags.Instance |
                BindingFlags.DeclaredOnly))
            .SelectMany(method => method.GetParameters())
            .Where(parameter => parameter.GetCustomAttribute<FromBodyAttribute>() is not null ||
                parameter.GetCustomAttribute<FromFormAttribute>() is not null).ToArray();
        Assert.NotEmpty(parameters);
        foreach (var parameter in parameters)
        {
            Assert.False(typeof(IBaseRequest).IsAssignableFrom(parameter.ParameterType),
                $"{parameter.Member.DeclaringType?.Name}.{parameter.Member.Name} binds a command/query directly.");
            AssertNoDomainType(parameter.ParameterType, parameter.Member.Name);
        }
    }

    [Fact]
    public void Every_http_contract_is_compiled_and_does_not_expose_domain_entities_or_mediator_requests()
    {
        var root = FindRepositoryRoot();
        var files = Directory.EnumerateFiles(Path.Combine(root, "backend", "caresitter-be", "Modules"),
            "*.cs", SearchOption.AllDirectories).Where(path =>
            {
                var segments = path.Split(Path.DirectorySeparatorChar);
                var name = Path.GetFileNameWithoutExtension(path);
                return segments.Contains("Contracts") &&
                    (name.EndsWith("Request", StringComparison.Ordinal) ||
                     name.EndsWith("Response", StringComparison.Ordinal)) &&
                    !segments.Contains("bin") && !segments.Contains("obj");
            }).ToArray();
        Assert.NotEmpty(files);
        var types = ModuleAssemblies.SelectMany(assembly => assembly.GetTypes()).ToArray();
        foreach (var file in files)
        {
            var module = Path.GetRelativePath(Path.Combine(root, "backend", "caresitter-be", "Modules"), file)
                .Split(Path.DirectorySeparatorChar)[0];
            var name = Path.GetFileNameWithoutExtension(file);
            var type = Assert.Single(types, type => type.Assembly.GetName().Name ==
                $"CareSitter.Modules.{module}" && type.Name.Split('`')[0] == name);
            Assert.False(typeof(IBaseRequest).IsAssignableFrom(type), $"{type.FullName} is not a DTO.");
            AssertNoDomainType(type, name);
        }
    }

    // Compare both the HTTP DTO and its mapping against the old command's JSON
    // contract, including omitted optional fields. No provider or DB calls here.
    [Theory]
    [InlineData("otp", "{\"email\":\"customer@example.test\"}")]
    [InlineData("login", "{\"email\":\"customer@example.test\",\"otp\":\"123456\"}")]
    [InlineData("login", "{\"email\":\"customer@example.test\",\"otp\":\"123456\",\"requiredRole\":\"CAREGIVER\"}")]
    [InlineData("password", "{\"email\":\"customer@example.test\",\"password\":\"test-value\"}")]
    [InlineData("password", "{\"email\":\"customer@example.test\",\"password\":\"test-value\",\"requiredRole\":\"CUSTOMER\"}")]
    [InlineData("register", "{\"email\":\"customer@example.test\",\"fullName\":\"Nguyễn An\",\"roles\":[\"CUSTOMER\"]}")]
    [InlineData("register", "{\"email\":\"customer@example.test\",\"fullName\":\"Nguyễn An\",\"roles\":[\"CUSTOMER\",\"CAREGIVER\"],\"password\":\"test-value\",\"confirmPassword\":\"test-value\",\"phone\":\"0900000000\"}")]
    [InlineData("refresh", "{\"refreshToken\":\"test-token\"}")]
    [InlineData("profile", "{\"fullName\":\"Nguyễn An\",\"email\":\"customer@example.test\"}")]
    [InlineData("profile", "{\"fullName\":\"Nguyễn An\",\"email\":\"customer@example.test\",\"displayName\":\"An\",\"dateOfBirth\":\"1990-05-20\",\"gender\":\"FEMALE\"}")]
    [InlineData("booking", "{\"beneficiaryId\":\"11111111-1111-1111-1111-111111111111\",\"addressId\":\"22222222-2222-2222-2222-222222222222\",\"serviceTypeId\":\"33333333-3333-3333-3333-333333333333\",\"scheduledStart\":\"2026-10-10T08:00:00+07:00\",\"scheduledEnd\":\"2026-10-10T10:00:00+07:00\"}")]
    [InlineData("booking", "{\"beneficiaryId\":\"11111111-1111-1111-1111-111111111111\",\"addressId\":\"22222222-2222-2222-2222-222222222222\",\"serviceTypeId\":\"33333333-3333-3333-3333-333333333333\",\"scheduledStart\":\"2026-10-10T08:00:00+07:00\",\"scheduledEnd\":\"2026-10-10T10:00:00+07:00\",\"caregiverId\":\"44444444-4444-4444-4444-444444444444\",\"requiredSkills\":[\"elderly\",\"mobility\"],\"promotionCode\":\"PILOT\"}")]
    public void Request_json_and_mapping_preserve_the_existing_contract(string useCase, string json)
    {
        var (dto, command, oldCommand) = useCase switch
        {
            "otp" => Map<SendOtpRequest, SendOtpCommand>(json, request => request.ToCommand()),
            "login" => Map<LoginRequest, LoginCommand>(json, request => request.ToCommand()),
            "password" => Map<LoginWithPasswordRequest, LoginWithPasswordCommand>(json, request => request.ToCommand()),
            "register" => Map<RegisterRequest, RegisterCommand>(json, request => request.ToCommand()),
            "refresh" => Map<RefreshTokenRequest, RefreshTokenCommand>(json, request => request.ToCommand()),
            "profile" => Map<UpdateProfileRequest, UpdateProfileCommand>(json, request => request.ToCommand()),
            "booking" => Map<CreateBookingRequest, CreateBookingCommand>(json, request => request.ToCommand()),
            _ => throw new ArgumentOutOfRangeException(nameof(useCase))
        };
        var expected = JsonSerializer.SerializeToNode(oldCommand, WebJson);
        Assert.True(JsonNode.DeepEquals(expected, JsonSerializer.SerializeToNode(dto, WebJson)),
            $"{useCase} HTTP JSON changed.");
        Assert.True(JsonNode.DeepEquals(expected, JsonSerializer.SerializeToNode(command, WebJson)),
            $"{useCase} mapping lost or changed fields.");
    }

    [Fact]
    public void Google_request_cannot_accept_a_client_selected_role()
    {
        var request = JsonSerializer.Deserialize<GoogleLoginRequest>(
            "{\"idToken\":\"test-token\",\"requiredRole\":\"ADMIN\"}", WebJson)!;
        Assert.Equal("test-token", request.IdToken);
        Assert.Equal(new[] { "idToken" }, JsonSerializer.SerializeToNode(request, WebJson)!
            .AsObject().Select(property => property.Key));
    }

    [Fact]
    public void Kyc_request_serializes_media_ids_and_not_public_urls()
    {
        var front = Guid.Parse("11111111-1111-1111-1111-111111111111");
        var back = Guid.Parse("22222222-2222-2222-2222-222222222222");
        var certificate = Guid.Parse("33333333-3333-3333-3333-333333333333");
        var request = new SubmitKycRequest("test-cccd", front, back, [certificate]);
        var json = JsonSerializer.SerializeToNode(request, WebJson)!.AsObject();
        Assert.Equal(new[] { "cccdNumber", "cccdFrontMediaId", "cccdBackMediaId", "certificateMediaIds" },
            json.Select(property => property.Key));
        Assert.Equal(front, json["cccdFrontMediaId"]!.GetValue<Guid>());
        Assert.Equal(back, json["cccdBackMediaId"]!.GetValue<Guid>());
        Assert.Equal(certificate, json["certificateMediaIds"]![0]!.GetValue<Guid>());
    }

    [Fact]
    public void Vnpay_ipn_keeps_provider_case_sensitive_response_keys()
    {
        var type = typeof(CareSitter.Modules.Payments.Controllers.VNPayController).Assembly.GetType(
            "CareSitter.Modules.Payments.Application.VNPay.Dtos.Responses.VnPayIpnResponse", true)!;
        var response = Activator.CreateInstance(type, "00", "Confirm Success")!;
        var json = JsonSerializer.SerializeToNode(response, WebJson)!.AsObject();
        Assert.Equal(new[] { "RspCode", "Message" }, json.Select(property => property.Key));
        Assert.Equal("00", json["RspCode"]!.GetValue<string>());
        Assert.Equal("Confirm Success", json["Message"]!.GetValue<string>());
    }

    [Fact]
    public void Booking_sync_omits_null_fields_but_keeps_empty_items_and_false_has_more()
    {
        var time = DateTimeOffset.Parse("2026-10-04T08:00:00+07:00");
        var reset = JsonSerializer.SerializeToNode(new BookingSyncResponse(null, 42, time, null, true), WebJson)!
            .AsObject();
        Assert.False(reset.ContainsKey("items"));
        Assert.False(reset.ContainsKey("hasMore"));
        Assert.True(reset["resetRequired"]!.GetValue<bool>());
        Assert.Equal(42, reset["nextCursor"]!.GetValue<long>());
        var normal = JsonSerializer.SerializeToNode(new BookingSyncResponse([], 42, time, false, false), WebJson)!
            .AsObject();
        Assert.Empty(normal["items"]!.AsArray());
        Assert.False(normal["hasMore"]!.GetValue<bool>());
    }

    private static (object Dto, object Command, object OldCommand) Map<TDto, TCommand>(
        string json, Func<TDto, TCommand> mapper) where TDto : class where TCommand : class
    {
        var dto = JsonSerializer.Deserialize<TDto>(json, WebJson)!;
        return (dto, mapper(dto), JsonSerializer.Deserialize<TCommand>(json, WebJson)!);
    }

    private static void AssertNoDomainType(Type type, string owner, HashSet<Type>? visited = null)
    {
        visited ??= [];
        if (!visited.Add(type)) return;
        Assert.False(type.Namespace?.StartsWith("CareSitter.Modules.", StringComparison.Ordinal) == true &&
            (type.Namespace.EndsWith(".Domain", StringComparison.Ordinal) ||
                type.Namespace.Contains(".Domain.", StringComparison.Ordinal)),
            $"{owner} exposes Domain type {type.FullName}.");
        if (type.HasElementType) AssertNoDomainType(type.GetElementType()!, owner, visited);
        foreach (var argument in type.GetGenericArguments()) AssertNoDomainType(argument, owner, visited);
        // Inspect module DTOs recursively; do not traverse the BCL object graph.
        if (type.Namespace?.StartsWith("CareSitter.Modules.", StringComparison.Ordinal) != true) return;
        foreach (var property in type.GetProperties(BindingFlags.Public | BindingFlags.Instance))
            AssertNoDomainType(property.PropertyType, $"{owner}.{property.Name}", visited);
    }

    private static string FindRepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);
        while (current is not null)
        {
            if (Directory.Exists(Path.Combine(current.FullName, "backend", "caresitter-be", "Modules")))
                return current.FullName;
            current = current.Parent;
        }
        throw new DirectoryNotFoundException("Could not locate the CareSitter repository root.");
    }
}
