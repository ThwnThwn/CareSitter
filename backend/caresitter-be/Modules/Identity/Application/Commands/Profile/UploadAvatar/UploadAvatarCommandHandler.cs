using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Application.UpdateProfile;
using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

internal sealed class UploadAvatarCommandHandler(
    IIdentityStore store, ICurrentUser currentUser, IMediaService mediaService)
    : IRequestHandler<UploadAvatarCommand, Result<AvatarResponse>>
{
    private static readonly HashSet<string> AllowedTypes =
        new(StringComparer.OrdinalIgnoreCase) { "image/jpeg", "image/png", "image/webp" };

    public async Task<Result<AvatarResponse>> Handle(UploadAvatarCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return IdentityManagementErrors.Unauthenticated();
        if (request.Length <= 0)
            return Error.Validation("avatar.empty", "File không được rỗng.");
        if (!AllowedTypes.Contains(request.ContentType))
            return Error.Validation("avatar.invalid_type", "Chỉ chấp nhận định dạng JPEG, PNG hoặc WebP.");
        if (request.Length > 5 * 1024 * 1024)
            return Error.Validation("avatar.too_large", "Ảnh không được vượt quá 5 MB.");

        var user = await store.FindUserByIdAsync(userId, ct);
        if (user is null) return IdentityManagementErrors.UserNotFound();
        var upload = await mediaService.UploadImageAsync(
            request.Content, request.FileName, "CareSitter/Avatars", ct);
        if (upload.IsFailure) return upload.Error;
        user.SetAvatar(upload.Value);
        await store.SaveChangesAsync(ct);
        return new AvatarResponse(upload.Value);
    }
}
