using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using Microsoft.AspNetCore.Authorization;
using System.Linq;

namespace HipodromoNacional.Pages.Caballos
{
    [Authorize]
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
            var all = await _repo.ObtenerTodosAsync();

            if (User.IsInRole("Propietario"))
            {
                var claim = User.FindFirst("PropietarioId");
                if (claim != null && int.TryParse(claim.Value, out int idProp))
                {
                    Caballos = all.Where(c => c.IdPropietario == idProp).ToList();
                    return;
                }
            }

            Caballos = all;
        }
    }
}
