using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using System.Text.Json;

namespace HipodromoNacional.Pages.Auditoria
{
    public class IndexModel : PageModel
    {
        private readonly IAuditoriaRepositorio _repo;

        public IndexModel(IAuditoriaRepositorio repo)
        {
            _repo = repo;
        }

        [BindProperty(SupportsGet = true)]
        public string? TablaSeleccionada { get; set; }

        public IEnumerable<string> Tablas { get; set; } = new List<string>();
        public IEnumerable<AuditoriaDTO> Registros { get; set; } = new List<AuditoriaDTO>();

        public async Task OnGetAsync()
        {
            try
            {
                Tablas = await _repo.ObtenerTablasConBitacoraAsync();

                if (!string.IsNullOrEmpty(TablaSeleccionada))
                {
                    Registros = await _repo.ObtenerPorTablaAsync(TablaSeleccionada);
                }
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = $"Error al consultar bitácora: {ex.Message}";
            }
        }

        public static string FormatearJson(string? json)
        {
            if (string.IsNullOrEmpty(json)) return "";
            try
            {
                var obj = JsonSerializer.Deserialize<object>(json);
                return JsonSerializer.Serialize(obj, new JsonSerializerOptions { WriteIndented = true });
            }
            catch
            {
                return json;
            }
        }
    }
}
