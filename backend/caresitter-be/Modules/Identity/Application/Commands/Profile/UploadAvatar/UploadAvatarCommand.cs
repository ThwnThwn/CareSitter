using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

public sealed record UploadAvatarCommand(
    Stream Content, string FileName, string ContentType, long Length)
    : IRequest<Result<AvatarResponse>>;
