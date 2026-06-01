using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using System.Data;
using Dapper;

namespace HipodromoNacional.Pages.EstablosMgt.Alimentacion
{
    public class CrearModel : PageModel
    {
        private readonly IAlimentacionRepositorio _repo;
        private readonly IDbConnection _db;

        public CrearModel(IAlimentacionRepositorio repo, IDbConnection db)
        {
            _repo = repo;
            _db = db;
        }

        [BindProperty]
        public AlimentacionDTO Alimentacion { get; set; } = new();

        public List<CaballoDTO> Caballos { get; set; } = new();
        public List<SuministroDTO> Suministros { get; set; } = new();

        public async Task OnGetAsync()
        {
            var caballos = await _db.QueryAsync<CaballoDTO>("SELECT id_caballo AS IdCaballo, nombre AS Nombre FROM caballo ORDER BY nombre");
            Caballos = caballos.ToList();

            var suministros = await _db.QueryAsync<SuministroDTO>("SELECT id_suministro AS IdSuministro, nombre_suministro AS NombreSuministro FROM suministro WHERE estado = 'Disponible' ORDER BY nombre_suministro");
            Suministros = suministros.ToList();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid) return Page();

            try
            {
                await _repo.CrearAlimentacionAsync(Alimentacion);
                TempData["SuccessMessage"] = "Registro de alimentación creado exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = $"Error al guardar: {ex.Message}";
                return Page();
            }
        }
    }
}
