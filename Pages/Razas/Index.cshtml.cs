using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using Microsoft.AspNetCore.Authorization;

namespace HipodromoNacional.Pages.Razas
{
    [Authorize(Roles = "Administrador")]
    public class IndexModel : PageModel
    {
        private readonly IRazaRepositorio _repo;

        public IndexModel(IRazaRepositorio repo)
        {
            _repo = repo;
        }

        public IEnumerable<RazaDTO> Razas { get; set; } = new List<RazaDTO>();

        public async Task OnGetAsync()
        {
            Razas = await _repo.ObtenerTodasAsync();
        }
    }
}
