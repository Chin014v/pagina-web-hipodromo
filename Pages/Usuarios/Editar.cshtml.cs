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
    public class EditarModel : PageModel
    {
        private readonly IUsuarioRepositorio _repo;
        private readonly IDbConnection _db;

        public EditarModel(IUsuarioRepositorio repo, IDbConnection db)
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

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var u = await _repo.ObtenerPorIdAsync(id);
            if (u == null) return NotFound();

            Usuario = u;
            await CargarListasAsync();
            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            ModelState.Remove("Usuario.Contrasena");

            if (Usuario.IdRol == 1)
            {
                Usuario.IdPropietario = null;
                Usuario.IdVeterinario = null;
                Usuario.IdEncargadoEstablo = null;
            }

            if (!ModelState.IsValid)
            {
                await CargarListasAsync();
                return Page();
            }

            try
            {
                await _repo.ActualizarUsuarioAsync(Usuario);
                TempData["SuccessMessage"] = "Usuario actualizado exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Exception ex)
            {
                ModelState.AddModelError(string.Empty, $"Error al actualizar: {ex.Message}");
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
