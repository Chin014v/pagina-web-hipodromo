using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Models;
using HipodromoNacional.Repositories;

namespace HipodromoNacional.Pages.Propietarios
{
    public class EditModel : PageModel
    {
        private readonly IPropietarioRepository _repo;

        public EditModel(IPropietarioRepository repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public PropietarioUpdateDTO Propietario { get; set; } = new();

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var p = await _repo.ObtenerPorIdAsync(id);
            if (p == null) return NotFound();

            Propietario = new PropietarioUpdateDTO
            {
                IdPropietario = p.IdPropietario,
                Nombre = p.Nombre,
                Apellido1 = p.Apellido1,
                Estado = p.Estado
            };

            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid) return Page();

            try
            {
                await _repo.ActualizarPropietarioAsync(Propietario);
                TempData["SuccessMessage"] = "Propietario actualizado exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = $"Error al actualizar: {ex.Message}";
                return Page();
            }
        }
    }
}
