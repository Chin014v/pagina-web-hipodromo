using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using System.Data;
using Dapper;

namespace HipodromoNacional.Pages.Veterinaria
{
    public class CrearModel : PageModel
    {
        private readonly IVeterinarioRepositorio _repo;
        private readonly IDbConnection _db;

        public CrearModel(IVeterinarioRepositorio repo, IDbConnection db)
        {
            _repo = repo;
            _db = db;
        }

        [BindProperty]
        public HistorialVeterinarioDTO Historial { get; set; } = new();

        public List<CaballoDTO> Caballos { get; set; } = new();
        public List<VeterinarioDTO> Veterinarios { get; set; } = new();

        public async Task OnGetAsync()
        {
            var caballos = await _db.QueryAsync<CaballoDTO>("SELECT id_caballo AS IdCaballo, nombre AS Nombre FROM caballo ORDER BY nombre");
            Caballos = caballos.ToList();

            var vets = await _db.QueryAsync<VeterinarioDTO>("SELECT id_veterinario AS IdVeterinario, nombre AS Nombre, apellido1 AS Apellido1 FROM veterinario WHERE estado = 'Activo' ORDER BY nombre");
            Veterinarios = vets.ToList();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid) return Page();

            try
            {
                await _repo.CrearHistorialAsync(Historial);
                TempData["SuccessMessage"] = "Registro veterinario creado exitosamente.";
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
