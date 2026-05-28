using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.Eventos
{
    public class CrearModel : PageModel
    {
        private readonly IEventoRepositorio _repo;

        public CrearModel(IEventoRepositorio repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public EventoDTO Evento { get; set; } = new();

        public void OnGet()
        {
        }

        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid) return Page();

            try
            {
                await _repo.CrearEventoAsync(Evento);
                TempData["SuccessMessage"] = "Evento programado exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = $"Error al guardar: {ex.Message}";
                return Page();
            }
        }
    }
}
