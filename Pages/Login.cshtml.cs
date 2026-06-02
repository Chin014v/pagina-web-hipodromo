using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using HipodromoNacional.Repositorios;
using System.ComponentModel.DataAnnotations;

namespace HipodromoNacional.Pages
{
    public class LoginModel : PageModel
    {
        private readonly IUsuarioRepositorio _repo;

        public LoginModel(IUsuarioRepositorio repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public LoginInput Input { get; set; } = new();

        public string? ErrorMessage { get; set; }

        public IActionResult OnGet()
        {
            if (User.Identity?.IsAuthenticated == true)
            {
                return RedirectToPage("/Index");
            }
            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid) return Page();

            var user = await _repo.ValidarUsuarioAsync(Input.Usuario, Input.Contrasena);
            if (user == null)
            {
                ErrorMessage = "Usuario o contraseña inválidos, o usuario inactivo.";
                return Page();
            }

            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.Name, user.Nombre!),
                new Claim(ClaimTypes.Role, user.NombreRol!)
            };

            if (user.IdPropietario.HasValue)
            {
                claims.Add(new Claim("PropietarioId", user.IdPropietario.Value.ToString()));
            }
            if (user.IdVeterinario.HasValue)
            {
                claims.Add(new Claim("VeterinarioId", user.IdVeterinario.Value.ToString()));
            }

            var claimsIdentity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
            var authProperties = new AuthenticationProperties { IsPersistent = false };

            await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, new ClaimsPrincipal(claimsIdentity), authProperties);

            return RedirectToPage("/Index");
        }

        public class LoginInput
        {
            [Required(ErrorMessage = "El usuario es obligatorio.")]
            public string Usuario { get; set; } = string.Empty;

            [Required(ErrorMessage = "La contraseña es obligatoria.")]
            [DataType(DataType.Password)]
            public string Contrasena { get; set; } = string.Empty;
        }
    }
}
