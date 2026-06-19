namespace Tracker.Models;

public static class StringExtensions
{
    /// <summary>Retourne la chaîne « trimmée », ou <c>null</c> si elle est vide ou ne contient que des espaces.</summary>
    public static string? NullIfBlank(this string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
