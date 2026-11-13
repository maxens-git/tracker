using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.EntityFrameworkCore;

namespace Tracker.Services;

/// <summary>Une écriture concurrente annule l'opération entière ; le client doit recharger l'état avant de réessayer.</summary>
public sealed class ConcurrencyExceptionFilter : IExceptionFilter
{
    public void OnException(ExceptionContext context)
    {
        if (context.Exception is not DbUpdateConcurrencyException)
            return;

        context.Result = new ConflictObjectResult(
            "Ce média a été modifié par une autre requête. Actualisez son état puis réessayez.");
        context.ExceptionHandled = true;
    }
}
