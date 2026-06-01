using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using Microsoft.AspNetCore.Authorization;

namespace HipodromoNacional.Pages.Usuarios
{
    [Authorize(Roles = "Administrador")]
    public class EliminarModel : PageModel
    {
        private readonly IUsuarioRepositorio _repo;

        public EliminarModel(IUsuarioRepositorio repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public UsuarioDTO Usuario { get; set; } = new();

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var u = await _repo.ObtenerPorIdAsync(id);
            if (u == null) return NotFound();

            Usuario = u;
            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            try
            {
                await _repo.EliminarUsuarioAsync(Usuario.IdUsuario);
                TempData["SuccessMessage"] = "Usuario eliminado exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Exception ex)
            {
                ModelState.AddModelError(string.Empty, $"Error al eliminar: {ex.Message}");
                return Page();
            }
        }
    }
}
