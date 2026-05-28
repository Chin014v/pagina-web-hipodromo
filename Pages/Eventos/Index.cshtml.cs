using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.Eventos
{
    public class IndexModel : PageModel
    {
        private readonly IEventoRepositorio _repo;

        public IndexModel(IEventoRepositorio repo)
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
