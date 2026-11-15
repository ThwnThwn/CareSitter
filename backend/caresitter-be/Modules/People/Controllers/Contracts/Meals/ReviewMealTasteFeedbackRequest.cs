using System.Text.Json.Serialization;

namespace CareSitter.Modules.People.Controllers;
public sealed record ReviewMealTasteFeedbackRequest([property: JsonRequired] bool Approve, long ExpectedHealthRevision);
