using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.Eventos
{
    public class EliminarModel : PageModel
    {
        private readonly IEventoRepositorio _repo;

        public EliminarModel(IEventoRepositorio repo)
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
                await _repo.EliminarEventoAsync(Evento.IdEvento);
                TempData["SuccessMessage"] = "Evento cancelado y eliminado exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = $"Error al eliminar: {ex.Message}";
                return RedirectToPage("./Index");
            }
        }
    }
}
