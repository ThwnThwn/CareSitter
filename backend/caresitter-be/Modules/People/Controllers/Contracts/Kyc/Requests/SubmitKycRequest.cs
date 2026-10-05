using CareSitter.Modules.People.Application;
using CareSitter.Modules.People.Application.Commands.ApproveCaregiverKyc;
using CareSitter.Modules.People.Application.Commands.CreateCaregiverProfile;
using CareSitter.Modules.People.Application.Commands.RejectCaregiverKyc;
using CareSitter.Modules.People.Application.Commands.SubmitCaregiverKyc;
using CareSitter.Modules.People.Application.Commands.UpdateCaregiverAvailabilityStatus;
using CareSitter.Modules.People.Application.Commands.UpdateCaregiverProfile;

namespace CareSitter.Modules.People.Controllers;

public sealed record SubmitKycRequest(
    string CccdNumber,
    Guid CccdFrontMediaId,
    Guid CccdBackMediaId,
    Guid[]? CertificateMediaIds = null);
