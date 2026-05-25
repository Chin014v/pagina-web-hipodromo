using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Models;
using HipodromoNacional.Repositories;

namespace HipodromoNacional.Pages.Eventos
{
    public class IndexModel : PageModel
    {
        private readonly IEventoRepository _repo;

        public IndexModel(IEventoRepository repo)
        {
            _repo = repo;
        }

        public IEnumerable<EventoDTO> Eventos { get; set; } = new List<EventoDTO>();

        public async Task OnGetAsync()
        {
            Eventos = await _repo.ObtenerTodosAsync();
        }
    }
}
