using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Models;
using HipodromoNacional.Repositories;

namespace HipodromoNacional.Pages.Caballos
{
    public class IndexModel : PageModel
    {
        private readonly ICaballoRepository _repo;

        public IndexModel(ICaballoRepository repo)
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
