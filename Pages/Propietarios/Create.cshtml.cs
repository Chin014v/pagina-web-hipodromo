using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Npgsql;
using HipodromoNacional.Models;
using HipodromoNacional.Repositories;
using System.Collections.Generic;
using System.Threading.Tasks;
using System;

namespace HipodromoNacional.Pages.Propietarios
{
    public class CreateModel : PageModel
    {
        private readonly IPropietarioRepository _repo;

        public CreateModel(IPropietarioRepository repo)
        {
            _repo = repo;
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

        public void OnGet()
        {
            // Initialization logic for dropdowns could go here
        }

        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid)
                return Page();

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
                return RedirectToPage("/Index");
            }
            catch (PostgresException ex)
            {
                TempData["ErrorMessage"] = $"Error en la base de datos: {ex.MessageText}";
                return Page();
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = $"Ocurrió un error inesperado: {ex.Message}";
                return Page();
            }
        }
    }
}
