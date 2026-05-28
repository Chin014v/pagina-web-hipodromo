using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.Eventos
{
    public class EditarModel : PageModel
    {
        private readonly IEventoRepositorio _repo;

        public EditarModel(IEventoRepositorio repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public EventoDTO Evento { get; set; } = new();

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var e = await _repo.ObtenerPorIdAsync(id);
            if (e == null) return NotFound();

            Evento = e;
            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            try
            {
                await _repo.ActualizarEventoAsync(Evento);
                TempData["SuccessMessage"] = "Evento actualizado exitosamente.";
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
