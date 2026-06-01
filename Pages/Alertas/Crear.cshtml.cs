using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using System.Data;
using Dapper;

namespace HipodromoNacional.Pages.Alertas
{
    public class CrearModel : PageModel
    {
        private readonly IAlertaRepositorio _repo;
        private readonly IDbConnection _db;

        public CrearModel(IAlertaRepositorio repo, IDbConnection db)
        {
            _repo = repo;
            _db = db;
        }

        [BindProperty]
        public int IdCaballo { get; set; }

        [BindProperty]
        public string Mensaje { get; set; } = string.Empty;

        public List<CaballoDTO> Caballos { get; set; } = new();

        public async Task OnGetAsync()
        {
            var list = await _db.QueryAsync<CaballoDTO>(@"
                SELECT id_caballo AS IdCaballo, nombre AS Nombre, codigo_unico AS CodigoUnico
                FROM caballo
                ORDER BY nombre");
            Caballos = list.ToList();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid || IdCaballo == 0)
            {
                await CargarCaballosAsync();
                return Page();
            }

            try
            {
                await _repo.CrearAlertaAsync(IdCaballo, Mensaje);
                TempData["SuccessMessage"] = "Alerta creada exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = $"Error al guardar: {ex.Message}";
                await CargarCaballosAsync();
                return Page();
            }
        }

        private async Task CargarCaballosAsync()
        {
            var list = await _db.QueryAsync<CaballoDTO>(@"
                SELECT id_caballo AS IdCaballo, nombre AS Nombre, codigo_unico AS CodigoUnico
                FROM caballo
                ORDER BY nombre");
            Caballos = list.ToList();
        }
    }
}