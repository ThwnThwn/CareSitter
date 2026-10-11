using System.Text.Json;
using CareSitter.Contracts.Nutrition;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.HealthProfile;

public sealed record UpdateHealthProfileCommand(Guid BeneficiaryId, long ExpectedHealthRevision,
    JsonElement Changes) : IRequest<Result<BeneficiaryHealthSnapshot>>;
