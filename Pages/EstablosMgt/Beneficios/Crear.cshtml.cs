using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using System.Data;
using Dapper;

namespace HipodromoNacional.Pages.EstablosMgt.Beneficios
{
    public class CrearModel : PageModel
    {
        private readonly IBeneficioRepositorio _repo;
        private readonly IDbConnection _db;

        public CrearModel(IBeneficioRepositorio repo, IDbConnection db)
        {
            _repo = repo;
            _db = db;
        }

        [BindProperty]
        public BeneficioPropietarioDTO Beneficio { get; set; } = new();

        public List<PropietarioDTO> Propietarios { get; set; } = new();

        public async Task OnGetAsync()
        {
            var propietarios = await _db.QueryAsync<PropietarioDTO>("SELECT id_propietario AS IdPropietario, nombre AS Nombre, apellido1 AS Apellido1 FROM propietario WHERE estado = 'Activo' ORDER BY nombre");
            Propietarios = propietarios.ToList();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid) return Page();

            try
            {
                await _repo.CrearBeneficioAsync(Beneficio);
                TempData["SuccessMessage"] = "Beneficio creado exitosamente.";
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
