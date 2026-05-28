using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.Caballos
{
    public class IndexModel : PageModel
    {
        private readonly ICaballoRepositorio _repo;

        public IndexModel(ICaballoRepositorio repo)
        {
            _repo = repo;
        }

        public IEnumerable<CaballoDTO> Caballos { get; set; } = new List<CaballoDTO>();

        public async Task OnGetAsync()
        {
            Caballos = await _repo.ObtenerTodosAsync();
        }
    }
}
