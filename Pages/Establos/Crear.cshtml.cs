using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using System.Data;
using Dapper;

namespace HipodromoNacional.Pages.Establos
{
    public class CrearModel : PageModel
    {
        private readonly IEstabloRepositorio _repo;
        private readonly IDbConnection _db;

        public CrearModel(IEstabloRepositorio repo, IDbConnection db)
        {
            _repo = repo;
            _db = db;
        }

        [BindProperty]
        public EstabloDTO Establo { get; set; } = new();

        public async Task OnGetAsync()
        {
            try
            {
                int maxId = await _db.ExecuteScalarAsync<int?>("SELECT MAX(id_establo) FROM public.establo") ?? 0;
                Establo.Codigo = $"EST-{(maxId + 1):D3}";
            }
            catch
            {
                Establo.Codigo = "EST-001";
            }
        }

        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid) return Page();

            try
            {
                await _repo.CrearEstabloAsync(Establo);
                TempData["SuccessMessage"] = "Establo registrado exitosamente.";
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
