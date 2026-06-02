using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using System.Data;
using Dapper;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Linq;
using System;

namespace HipodromoNacional.Pages.Caballos
{
    public class CrearModel : PageModel
    {
        private readonly ICaballoRepositorio _repo;
        private readonly IDbConnection _db;

        public CrearModel(ICaballoRepositorio repo, IDbConnection db)
        {
            _repo = repo;
            _db = db;
        }

        [BindProperty]
        public CaballoDTO Caballo { get; set; } = new();

        public List<dynamic> Razas { get; set; } = new();
        public List<dynamic> Propietarios { get; set; } = new();

        public async Task OnGetAsync()
        {
            await CargarListasAsync();
        }

        private async Task CargarListasAsync()
        {
            var razasQuery = await _db.QueryAsync<dynamic>("SELECT id_raza AS id, nombre_raza AS nombre FROM raza WHERE estado = 'Activo' ORDER BY nombre_raza");
            Razas = razasQuery.ToList();

            var propQuery = await _db.QueryAsync<dynamic>("SELECT id_propietario AS id, cedula || ' - ' || nombre || ' ' || apellido1 AS nombre_completo FROM propietario WHERE estado = 'Activo' ORDER BY nombre, apellido1");
            Propietarios = propQuery.ToList();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid)
            {
                await CargarListasAsync();
                return Page();
            }

            try
            {
                await _repo.CrearCaballoAsync(Caballo);
                TempData["SuccessMessage"] = "Caballo registrado exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Exception ex)
            {
                string message = ex.Message;
                if (message.Contains("caballo_codigo_unico_key") || message.Contains("23505") || message.Contains("duplicate key"))
                {
                    message = "El código único del caballo ya se encuentra registrado.";
                }
                TempData["ErrorMessage"] = $"Error al guardar: {message}";
                await CargarListasAsync();
                return Page();
            }
        }
    }
}
