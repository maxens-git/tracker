using Microsoft.Extensions.Options;
using Novell.Directory.Ldap;
using Tracker.Options;

namespace Tracker.Services;

public interface ILdapService
{
    Task<bool> AuthenticateAsync(string username, string password);
}

public class LdapService : ILdapService
{
    private readonly LdapOptions _options;
    private readonly ILogger<LdapService> _logger;

    public LdapService(IOptions<LdapOptions> options, ILogger<LdapService> logger)
    {
        _options = options.Value;
        _logger = logger;
    }

    public async Task<bool> AuthenticateAsync(string username, string password)
    {
        if (string.IsNullOrWhiteSpace(_options.Server))
        {
            _logger.LogWarning("LDAP server not configured, authentication skipped");
            return false;
        }

        try
        {
            using LdapConnection connection = new();

            if (_options.UseSsl)
            {
                connection.SecureSocketLayer = true;
            }

            await Task.Run(() => connection.Connect(_options.Server, _options.Port));

            string userDn = string.Format(_options.UserDnPattern, username);

            if (!string.IsNullOrEmpty(_options.SearchFilter) && !string.IsNullOrEmpty(_options.BindDn))
            {
                await Task.Run(() => connection.Bind(_options.BindDn, _options.BindPassword));

                string searchFilter = string.Format(_options.SearchFilter, username);
                ILdapSearchResults? results = await Task.Run(() =>
                    connection.Search(
                        _options.BaseDn,
                        LdapConnection.ScopeSub,
                        searchFilter,
                        null,
                        false
                    )
                );

                if (results.HasMore())
                {
                    LdapEntry entry = results.Next();
                    userDn = entry.Dn;
                }
                else
                {
                    _logger.LogWarning("User {Username} not found in LDAP", username);
                    return false;
                }

                connection.Disconnect();
                connection.Connect(_options.Server, _options.Port);
            }

            await Task.Run(() => connection.Bind(userDn, password));

            bool authenticated = connection.Bound;

            if (authenticated)
            {
                _logger.LogInformation("User {Username} authenticated via LDAP", username);
            }

            return authenticated;
        }
        catch (LdapException ex)
        {
            _logger.LogWarning(ex, "LDAP authentication failed for user {Username}", username);
            return false;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error during LDAP authentication for user {Username}", username);
            return false;
        }
    }
}
