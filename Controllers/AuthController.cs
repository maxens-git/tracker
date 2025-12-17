using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly ILdapService _ldapService;
    private readonly IJwtService _jwtService;
    private readonly ILogger<AuthController> _logger;

    public AuthController(
        ILdapService ldapService,
        IJwtService jwtService,
        ILogger<AuthController> logger)
    {
        _ldapService = ldapService;
        _jwtService = jwtService;
        _logger = logger;
    }

    [HttpPost("login")]
    public async Task<ActionResult<TokenResponse>> Login([FromBody] LoginRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Username) || string.IsNullOrWhiteSpace(request.Password))
        {
            return BadRequest("Username and password are required");
        }

        try
        {
            var isAuthenticated = await _ldapService.AuthenticateAsync(request.Username, request.Password);

            if (!isAuthenticated)
            {
                _logger.LogWarning("Failed login attempt for user: {Username}", request.Username);
                return Unauthorized("Invalid credentials");
            }

            var tokenResponse = await _jwtService.GenerateTokensAsync(request.Username);
            _logger.LogInformation("User {Username} logged in successfully", request.Username);

            return Ok(tokenResponse);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during login for user: {Username}", request.Username);
            return StatusCode(500, "An error occurred during authentication");
        }
    }

    [HttpPost("refresh")]
    public async Task<ActionResult<TokenResponse>> Refresh([FromBody] RefreshRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.RefreshToken))
        {
            return BadRequest("Refresh token is required");
        }

        try
        {
            var tokenResponse = await _jwtService.RefreshTokenAsync(request.RefreshToken);

            if (tokenResponse == null)
            {
                return Unauthorized("Invalid or expired refresh token");
            }

            _logger.LogInformation("Token refreshed for user: {Username}", tokenResponse.Username);
            return Ok(tokenResponse);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during token refresh");
            return StatusCode(500, "An error occurred during token refresh");
        }
    }

    [Authorize]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout([FromBody] RefreshRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.RefreshToken))
        {
            return BadRequest("Refresh token is required");
        }

        try
        {
            var success = await _jwtService.RevokeTokenAsync(request.RefreshToken);

            if (!success)
            {
                return BadRequest("Token not found or already revoked");
            }

            _logger.LogInformation("Token revoked successfully");
            return Ok(new { message = "Token revoked successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during logout");
            return StatusCode(500, "An error occurred during logout");
        }
    }

    [Authorize]
    [HttpPost("logout-all")]
    public async Task<IActionResult> LogoutAll()
    {
        try
        {
            var username = User.Identity?.Name;

            if (string.IsNullOrEmpty(username))
            {
                return Unauthorized();
            }

            await _jwtService.RevokeAllUserTokensAsync(username);

            _logger.LogInformation("All tokens revoked for user: {Username}", username);
            return Ok(new { message = "All tokens revoked successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during logout-all");
            return StatusCode(500, "An error occurred during logout");
        }
    }

    [Authorize]
    [HttpGet("validate")]
    public IActionResult Validate()
    {
        var username = User.Identity?.Name;
        return Ok(new { valid = true, username });
    }
}
