namespace Tracker.Options;

public class LdapOptions
{
    public const string SectionName = "Ldap";
    
    public string Server { get; set; } = string.Empty;
    public int Port { get; set; } = 389;
    public bool UseSsl { get; set; } = false;
    public string BaseDn { get; set; } = string.Empty;
    public string UserDnPattern { get; set; } = "uid={0},ou=users,dc=example,dc=com";
    public string? SearchFilter { get; set; }
    public string? BindDn { get; set; }
    public string? BindPassword { get; set; }
}
