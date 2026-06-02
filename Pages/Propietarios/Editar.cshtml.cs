using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.Propietarios
{
    public class EditarModel : PageModel
    {
        private readonly IPropietarioRepositorio _repo;

        public EditarModel(IPropietarioRepositorio repo)
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
                bool success = await _repo.ActualizarPropietarioAsync(Propietario);
                if (!success)
                {
                    TempData["ErrorMessage"] = "No se encontró el propietario especificado o no hubo cambios.";
                    return Page();
                }
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
