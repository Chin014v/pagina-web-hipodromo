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

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var u = await _repo.ObtenerPorIdAsync(id);
            if (u == null) return NotFound();

            Usuario = u;
            Roles = await _repo.ObtenerRolesAsync();
            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            ModelState.Remove("Usuario.Contrasena");

            if (!ModelState.IsValid)
            {
                Roles = await _repo.ObtenerRolesAsync();
                return Page();
            }

            try
            {
                bool success = await _repo.ActualizarUsuarioAsync(Usuario);
                if (!success)
                {
                    ModelState.AddModelError(string.Empty, "No se encontró el usuario o no hubo cambios.");
                    Roles = await _repo.ObtenerRolesAsync();
                    return Page();
                }
                TempData["SuccessMessage"] = "Usuario actualizado exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Exception ex)
            {
                ModelState.AddModelError(string.Empty, $"Error al actualizar: {ex.Message}");
                Roles = await _repo.ObtenerRolesAsync();
                return Page();
            }
        }
    }
}
