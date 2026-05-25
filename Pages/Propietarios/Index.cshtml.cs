using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Models;
using HipodromoNacional.Repositories;

namespace HipodromoNacional.Pages.Propietarios
{
    public class IndexModel : PageModel
    {
        private readonly IPropietarioRepository _repo;

        public IndexModel(IPropietarioRepository repo)
        {
            _repo = repo;
        }

        public IEnumerable<PropietarioDTO> Propietarios { get; set; } = new List<PropietarioDTO>();

        public async Task OnGetAsync()
        {
            Propietarios = await _repo.ObtenerTodosAsync();
        }
    }
}
