using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.EstablosMgt.Suministros
{
    public class IndexModel : PageModel
    {
        private readonly ISuministroRepositorio _repo;

        public IndexModel(ISuministroRepositorio repo)
        {
            _repo = repo;
        }

        public IEnumerable<SuministroDTO> Suministros { get; set; } = new List<SuministroDTO>();

        public async Task OnGetAsync()
        {
            Suministros = await _repo.ObtenerTodosAsync();
        }
    }
}
