using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.EstablosMgt.Alimentacion
{
    public class IndexModel : PageModel
    {
        private readonly IAlimentacionRepositorio _repo;

        public IndexModel(IAlimentacionRepositorio repo)
        {
            _repo = repo;
        }

        public IEnumerable<AlimentacionDTO> Alimentaciones { get; set; } = new List<AlimentacionDTO>();

        public async Task OnGetAsync()
        {
            Alimentaciones = await _repo.ObtenerTodosAsync();
        }
    }
}
