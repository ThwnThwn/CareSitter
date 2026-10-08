using CareSitter.Modules.Identity.Application;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace CareSitter.Modules.Identity.Controllers;

public sealed class IdentityConcurrencyExceptionFilter : IExceptionFilter
{
    public void OnException(ExceptionContext context)
    {
        if (context.Exception is not AuthenticationStateChangedException) return;
        context.Result = new ConflictObjectResult(new ProblemDetails
        { Title = "auth.state_changed", Detail = "Thông tin bảo mật đã thay đổi. Vui lòng đăng nhập lại." });
        context.ExceptionHandled = true;
    }
}
