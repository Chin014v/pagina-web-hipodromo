using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Npgsql;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using System.Collections.Generic;
using System.Threading.Tasks;
using System;
using System.Data;
using Dapper;
using System.Linq;

namespace HipodromoNacional.Pages.Propietarios
{
    public class CrearModel : PageModel
    {
        private readonly IPropietarioRepositorio _repo;
        private readonly IDbConnection _db;

        public CrearModel(IPropietarioRepositorio repo, IDbConnection db)
        {
            _repo = repo;
            _db = db;
        }

        [BindProperty]
        public PropietarioDTO Propietario { get; set; } = new PropietarioDTO();

        [BindProperty]
        public List<string> Telefonos { get; set; } = new List<string>();
        [BindProperty]
        public List<string> TiposTelefonos { get; set; } = new List<string>();
        
        [BindProperty]
        public List<string> Correos { get; set; } = new List<string>();
        [BindProperty]
        public List<string> TiposCorreos { get; set; } = new List<string>();

        public List<dynamic> Paises { get; set; } = new List<dynamic>();

        public async Task OnGetAsync()
        {
            var list = await _db.QueryAsync<dynamic>("SELECT id_pais AS id, nombre_pais AS nombre FROM pais ORDER BY nombre_pais");
            Paises = list.ToList();
        }

        public async Task<JsonResult> OnGetProvinciasAsync(int paisId)
        {
            var list = await _db.QueryAsync<dynamic>("SELECT id_provincia AS id, nombre_provincia AS nombre FROM provincia WHERE id_pais = @PaisId ORDER BY nombre_provincia", new { PaisId = paisId });
            return new JsonResult(list);
        }

        public async Task<JsonResult> OnGetCantonesAsync(int provinciaId)
        {
            var list = await _db.QueryAsync<dynamic>("SELECT id_canton AS id, nombre_canton AS nombre FROM canton WHERE id_provincia = @ProvinciaId ORDER BY nombre_canton", new { ProvinciaId = provinciaId });
            return new JsonResult(list);
        }

        public async Task<JsonResult> OnGetDistritosAsync(int cantonId)
        {
            var list = await _db.QueryAsync<dynamic>("SELECT id_distrito AS id, nombre_distrito AS nombre FROM distrito WHERE id_canton = @CantonId ORDER BY nombre_distrito", new { CantonId = cantonId });
            return new JsonResult(list);
        }

        public async Task<JsonResult> OnGetBarriosAsync(int distritoId)
        {
            var list = await _db.QueryAsync<dynamic>("SELECT id_barrio AS id, nombre_barrio AS nombre FROM barrio WHERE id_distrito = @DistritoId ORDER BY nombre_barrio", new { DistritoId = distritoId });
            return new JsonResult(list);
        }

        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid)
            {
                var list = await _db.QueryAsync<dynamic>("SELECT id_pais AS id, nombre_pais AS nombre FROM pais ORDER BY nombre_pais");
                Paises = list.ToList();
                return Page();
            }

            try
            {
                await _repo.CrearPropietarioAsync(
                    Propietario, 
                    Telefonos.ToArray(), 
                    TiposTelefonos.ToArray(), 
                    Correos.ToArray(), 
                    TiposCorreos.ToArray()
                );

                TempData["SuccessMessage"] = "Propietario creado exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (PostgresException ex)
            {
                TempData["ErrorMessage"] = $"Error en la base de datos: {ex.MessageText}";
                var list = await _db.QueryAsync<dynamic>("SELECT id_pais AS id, nombre_pais AS nombre FROM pais ORDER BY nombre_pais");
                Paises = list.ToList();
                return Page();
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = $"Ocurrió un error inesperado: {ex.Message}";
                var list = await _db.QueryAsync<dynamic>("SELECT id_pais AS id, nombre_pais AS nombre FROM pais ORDER BY nombre_pais");
                Paises = list.ToList();
                return Page();
            }
        }
    }
}
