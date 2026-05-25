using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Models;
using HipodromoNacional.Repositories;

namespace HipodromoNacional.Pages.Establos
{
    public class IndexModel : PageModel
    {
        private readonly IEstabloRepository _repo;

        public IndexModel(IEstabloRepository repo)
        {
            _repo = repo;
        }

        public IEnumerable<EstabloDTO> Establos { get; set; } = new List<EstabloDTO>();

        public async Task OnGetAsync()
        {
            Establos = await _repo.ObtenerTodosAsync();
        }
    }
}
