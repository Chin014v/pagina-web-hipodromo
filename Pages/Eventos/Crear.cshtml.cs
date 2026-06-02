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
            var now = DateTime.Now;
            Evento.Fecha = new DateTime(now.Year, now.Month, now.Day, now.Hour, now.Minute, 0, 0);
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
                string message = ex.Message;
                if (message.Contains("evento_codigo_evento_key") || message.Contains("23505") || message.Contains("duplicate key"))
                {
                    message = "El código del evento ya se encuentra registrado.";
                }
                TempData["ErrorMessage"] = $"Error al guardar: {message}";
                return Page();
            }
        }
    }
}
