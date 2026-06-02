using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using Microsoft.AspNetCore.Authorization;
using System.Linq;

namespace HipodromoNacional.Pages.Inscripciones
{
    [Authorize]
    public class IndexModel : PageModel
    {
        private readonly IInscripcionRepositorio _repo;
        private readonly ICaballoRepositorio _caballoRepo;

        public IndexModel(IInscripcionRepositorio repo, ICaballoRepositorio caballoRepo)
        {
            _repo = repo;
            _caballoRepo = caballoRepo;
        }

        public IEnumerable<InscripcionDTO> Inscripciones { get; set; } = new List<InscripcionDTO>();

        public async Task OnGetAsync()
        {
            var all = await _repo.ObtenerTodosAsync();

            if (User.IsInRole("Propietario"))
            {
                var claim = User.FindFirst("PropietarioId");
                if (claim != null && int.TryParse(claim.Value, out int idProp))
                {
                    var horses = await _caballoRepo.ObtenerTodosAsync();
                    var ownerHorseIds = horses.Where(h => h.IdPropietario == idProp).Select(h => h.IdCaballo).ToHashSet();
                    Inscripciones = all.Where(i => ownerHorseIds.Contains(i.IdCaballo)).ToList();
                    return;
                }
            }

            Inscripciones = all;
        }
    }
}
