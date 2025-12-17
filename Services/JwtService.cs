using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Tracker.Data;
using Tracker.Models.Auth;
using Tracker.ModelsDTO;
using Tracker.Options;

namespace Tracker.Services;

public interface IJwtService
{
    Task<TokenResponse> GenerateTokensAsync(string username);
    Task<TokenResponse?> RefreshTokenAsync(string refreshToken);
    Task<bool> RevokeTokenAsync(string refreshToken);
    Task RevokeAllUserTokensAsync(string username);
    ClaimsPrincipal? ValidateAccessToken(string token);
}

public class JwtService : IJwtService
{
    private readonly JwtOptions _options;
    private readonly ApiDbContext _context;
    private readonly ILogger<JwtService> _logger;

    public JwtService(IOptions<JwtOptions> options, ApiDbContext context, ILogger<JwtService> logger)
    {
        _options = options.Value;
        _context = context;
        _logger = logger;
    }

    public async Task<TokenResponse> GenerateTokensAsync(string username)
    {
        DateTime accessTokenExpiry = DateTime.UtcNow.AddMinutes(_options.AccessTokenExpirationMinutes);
        string accessToken = GenerateAccessToken(username, accessTokenExpiry);

        RefreshToken refreshToken = await CreateRefreshTokenAsync(username);

        return new TokenResponse
        {
            AccessToken = accessToken,
            RefreshToken = refreshToken.Token,
            ExpiresAt = accessTokenExpiry,
            Username = username
        };
    }

    public async Task<TokenResponse?> RefreshTokenAsync(string refreshToken)
    {
        RefreshToken? storedToken = await _context.RefreshTokens
            .FirstOrDefaultAsync(t => t.Token == refreshToken);

        if (storedToken == null)
        {
            _logger.LogWarning("Refresh token not found");
            return null;
        }

        if (!storedToken.IsActive)
        {
            _logger.LogWarning("Refresh token is not active (expired or revoked)");
            return null;
        }

        storedToken.RevokedAt = DateTime.UtcNow;

        DateTime accessTokenExpiry = DateTime.UtcNow.AddMinutes(_options.AccessTokenExpirationMinutes);
        string newAccessToken = GenerateAccessToken(storedToken.Username, accessTokenExpiry);

        RefreshToken newRefreshToken = await CreateRefreshTokenAsync(storedToken.Username);
        storedToken.ReplacedByToken = newRefreshToken.Token;

        await _context.SaveChangesAsync();

        _logger.LogInformation("Refreshed tokens for user {Username}", storedToken.Username);

        return new TokenResponse
        {
            AccessToken = newAccessToken,
            RefreshToken = newRefreshToken.Token,
            ExpiresAt = accessTokenExpiry,
            Username = storedToken.Username
        };
    }

    public async Task<bool> RevokeTokenAsync(string refreshToken)
    {
        RefreshToken? storedToken = await _context.RefreshTokens
            .FirstOrDefaultAsync(t => t.Token == refreshToken);

        if (storedToken != null && storedToken.IsActive)
        {
            storedToken.RevokedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
            _logger.LogInformation("Revoked refresh token for user {Username}", storedToken.Username);
            return true;
        }

        return false;
    }

    public async Task RevokeAllUserTokensAsync(string username)
    {
        List<RefreshToken> activeTokens = await _context.RefreshTokens
            .Where(t => t.Username == username && t.RevokedAt == null && t.ExpiresAt > DateTime.UtcNow)
            .ToListAsync();

        foreach (RefreshToken token in activeTokens)
        {
            token.RevokedAt = DateTime.UtcNow;
        }

        await _context.SaveChangesAsync();
        _logger.LogInformation("Revoked all tokens for user {Username}", username);
    }

    public ClaimsPrincipal? ValidateAccessToken(string token)
    {
        TokenValidationParameters parameters = new()
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = _options.Issuer,
            ValidAudience = _options.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.Secret))
        };

        try
        {
            JwtSecurityTokenHandler handler = new();
            return handler.ValidateToken(token, parameters, out _);
        }
        catch
        {
            return null;
        }
    }

    private string GenerateAccessToken(string username, DateTime expiry)
    {
        SymmetricSecurityKey key = new(Encoding.UTF8.GetBytes(_options.Secret));
        SigningCredentials credentials = new(key, SecurityAlgorithms.HmacSha256);

        Claim[] claims =
        [
            new(ClaimTypes.Name, username),
            new(JwtRegisteredClaimNames.Sub, username),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new(JwtRegisteredClaimNames.Iat, DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString(), ClaimValueTypes.Integer64)
        ];

        JwtSecurityToken token = new(
            issuer: _options.Issuer,
            audience: _options.Audience,
            claims: claims,
            expires: expiry,
            signingCredentials: credentials
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private async Task<RefreshToken> CreateRefreshTokenAsync(string username)
    {
        RefreshToken refreshToken = new()
        {
            Token = GenerateSecureToken(),
            Username = username,
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(_options.RefreshTokenExpirationDays)
        };

        _context.RefreshTokens.Add(refreshToken);
        await _context.SaveChangesAsync();

        return refreshToken;
    }

    private static string GenerateSecureToken()
    {
        byte[] randomBytes = new byte[64];
        using RandomNumberGenerator rng = RandomNumberGenerator.Create();
        rng.GetBytes(randomBytes);
        return Convert.ToBase64String(randomBytes);
    }
}
