using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.EstablosMgt.Beneficios
{
    public class IndexModel : PageModel
    {
        private readonly IBeneficioRepositorio _repo;

        public IndexModel(IBeneficioRepositorio repo)
        {
            _repo = repo;
        }

        public IEnumerable<BeneficioPropietarioDTO> Beneficios { get; set; } = new List<BeneficioPropietarioDTO>();

        public async Task OnGetAsync()
        {
            Beneficios = await _repo.ObtenerTodosAsync();
        }
    }
}
