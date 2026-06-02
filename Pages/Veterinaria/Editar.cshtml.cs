using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using Dapper;

namespace HipodromoNacional.Pages.Veterinaria
{
    public class EditarModel : PageModel
    {
        private readonly IVeterinarioRepositorio _repo;
        private readonly System.Data.IDbConnection _db;

        public EditarModel(IVeterinarioRepositorio repo, System.Data.IDbConnection db)
        {
            _repo = repo;
            _db = db;
        }

        [BindProperty]
        public HistorialVeterinarioDTO Historial { get; set; } = new();

        [BindProperty]
        public string EstadoSaludCaballo { get; set; } = "Saludable";

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var item = await _repo.ObtenerPorIdAsync(id);
            if (item == null) return NotFound();

            Historial = item;
            
            // Obtener el estado de salud actual del caballo
            EstadoSaludCaballo = await _db.ExecuteScalarAsync<string>("SELECT estado_salud FROM public.caballo WHERE id_caballo = @IdCaballo", new { IdCaballo = Historial.IdCaballo }) ?? "Saludable";

            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            ModelState.Remove("Historial.IdCaballo");
            ModelState.Remove("Historial.IdVeterinario");
            ModelState.Remove("Historial.CodigoRegistro");
            ModelState.Remove("Historial.Diagnostico");
            ModelState.Remove("Historial.Tratamiento");
            ModelState.Remove("Historial.FechaRevision");
            
            if (!ModelState.IsValid) return Page();

            try
            {
                var original = await _repo.ObtenerPorIdAsync(Historial.IdHistorial);
                if (original == null)
                {
                    TempData["ErrorMessage"] = "No se encontró el registro original.";
                    return RedirectToPage("./Index");
                }

                // Enforce that the expiration date cannot be set earlier than the original date
                if (Historial.FechaVencimientoCertificado < original.FechaVencimientoCertificado)
                {
                    ModelState.AddModelError("Historial.FechaVencimientoCertificado", $"La fecha de vencimiento no puede ser anterior a la fecha previa ({original.FechaVencimientoCertificado:dd/MM/yyyy}).");
                    return Page();
                }

                // Auto-activate to true if the expiration date is set in the future
                var today = DateOnly.FromDateTime(DateTime.Today);
                if (Historial.FechaVencimientoCertificado > today)
                {
                    Historial.CertificadoVigente = true;
                }

                // Keep IdCaballo from original since it is removed from model state validation and not posted back
                Historial.IdCaballo = original.IdCaballo;

                bool success = await _repo.ActualizarHistorialAsync(Historial);
                if (!success)
                {
                    TempData["ErrorMessage"] = "No se encontró el registro veterinario o no hubo cambios.";
                    return Page();
                }

                // Actualizar el estado de salud del caballo
                await _db.ExecuteAsync("UPDATE public.caballo SET estado_salud = @Estado WHERE id_caballo = @IdCaballo", new { Estado = EstadoSaludCaballo, IdCaballo = Historial.IdCaballo });

                TempData["SuccessMessage"] = "Registro veterinario actualizado exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = $"Error al actualizar: {ex.Message}";
                return Page();
            }
        }
    }
}
