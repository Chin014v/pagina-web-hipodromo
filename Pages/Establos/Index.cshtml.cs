using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.Establos
{
    public class IndexModel : PageModel
    {
        private readonly IEstabloRepositorio _repo;

        public IndexModel(IEstabloRepositorio repo)
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
