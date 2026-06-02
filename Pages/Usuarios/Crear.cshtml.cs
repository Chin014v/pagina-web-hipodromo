using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using Microsoft.AspNetCore.Authorization;
using System.Data;
using Dapper;

namespace HipodromoNacional.Pages.Usuarios
{
    [Authorize(Roles = "Administrador")]
    public class CrearModel : PageModel
    {
        private readonly IUsuarioRepositorio _repo;
        private readonly IDbConnection _db;

        public CrearModel(IUsuarioRepositorio repo, IDbConnection db)
        {
            _repo = repo;
            _db = db;
        }

        [BindProperty]
        public UsuarioDTO Usuario { get; set; } = new();

        public IEnumerable<RolDTO> Roles { get; set; } = new List<RolDTO>();
        public IEnumerable<PersonaLookupDTO> Propietarios { get; set; } = new List<PersonaLookupDTO>();
        public IEnumerable<PersonaLookupDTO> Veterinarios { get; set; } = new List<PersonaLookupDTO>();
        public IEnumerable<PersonaLookupDTO> Encargados { get; set; } = new List<PersonaLookupDTO>();

        public async Task OnGetAsync()
        {
            await CargarListasAsync();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            if (string.IsNullOrEmpty(Usuario.Contrasena))
            {
                ModelState.AddModelError("Usuario.Contrasena", "La contraseña es obligatoria para crear un usuario.");
            }

            if (!ModelState.IsValid)
            {
                await CargarListasAsync();
                return Page();
            }

            try
            {
                await _repo.CrearUsuarioAsync(Usuario);
                TempData["SuccessMessage"] = "Usuario creado exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Npgsql.PostgresException ex)
            {
                string message = ex.MessageText;
                if (ex.SqlState == "23505" || ex.ConstraintName == "usuario_nombre_key" || message.Contains("usuario_nombre_key") || message.Contains("23505"))
                {
                    message = "El nombre de usuario ya se encuentra registrado.";
                }
                ModelState.AddModelError(string.Empty, $"Error al registrar usuario: {message}");
                await CargarListasAsync();
                return Page();
            }
            catch (Exception ex)
            {
                string message = ex.Message;
                if (message.Contains("usuario_nombre_key", StringComparison.OrdinalIgnoreCase) || message.Contains("23505") || message.Contains("duplicate key", StringComparison.OrdinalIgnoreCase))
                {
                    message = "El nombre de usuario ya se encuentra registrado.";
                }
                ModelState.AddModelError(string.Empty, $"Error al registrar usuario: {message}");
                await CargarListasAsync();
                return Page();
            }
        }

        private async Task CargarListasAsync()
        {
            Roles = await _repo.ObtenerRolesAsync();
            Propietarios = await _db.QueryAsync<PersonaLookupDTO>(
                "SELECT id_propietario AS Id, nombre || ' ' || apellido1 AS Nombre FROM propietario WHERE estado = 'Activo' ORDER BY nombre");
            Veterinarios = await _db.QueryAsync<PersonaLookupDTO>(
                "SELECT id_veterinario AS Id, nombre || ' ' || apellido1 AS Nombre FROM veterinario WHERE estado = 'Activo' ORDER BY nombre");

            var rolEncargado = await _db.QueryFirstOrDefaultAsync<int?>(
                "SELECT id_rol FROM rol WHERE nombre_rol = 'EncargadoEstablo'");
            if (rolEncargado.HasValue)
            {
                Encargados = await _db.QueryAsync<PersonaLookupDTO>(
                    "SELECT id_usuario AS Id, nombre AS Nombre FROM usuario WHERE id_rol = @RolId AND activo = true ORDER BY nombre",
                    new { RolId = rolEncargado.Value });
            }
        }
    }
}
