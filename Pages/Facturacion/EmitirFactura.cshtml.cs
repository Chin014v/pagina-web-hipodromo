using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using System.Collections.Generic;
using System.Threading.Tasks;
using System;

namespace HipodromoNacional.Pages.Facturacion
{
    public class EmitirFacturaModel : PageModel
    {
        private readonly IFacturacionRepositorio _facturacionRepo;
        private readonly IPropietarioRepositorio _propietarioRepo;
        private readonly IEventoRepositorio _eventoRepo;

        public EmitirFacturaModel(
            IFacturacionRepositorio facturacionRepo,
            IPropietarioRepositorio propietarioRepo,
            IEventoRepositorio eventoRepo)
        {
            _facturacionRepo = facturacionRepo;
            _propietarioRepo = propietarioRepo;
            _eventoRepo = eventoRepo;
        }

        public IEnumerable<PropietarioDTO> Propietarios { get; set; } = new List<PropietarioDTO>();
        public IEnumerable<EventoDTO> Eventos { get; set; } = new List<EventoDTO>();

        [BindProperty]
        public int IdPropietario { get; set; }
        [BindProperty]
        public int IdEvento { get; set; }
        [BindProperty]
        public int? IdMetodoPago { get; set; }
        [BindProperty]
        public string Referencia { get; set; } = string.Empty;
        [BindProperty]
        public string NumeroComprobante { get; set; } = string.Empty;

        public async Task OnGetAsync()
        {
            Propietarios = await _propietarioRepo.ObtenerTodosAsync();
            Eventos = await _eventoRepo.ObtenerTodosAsync();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            try
            {
                int newInvoiceId = await _facturacionRepo.CrearFacturaAsync(
                    IdPropietario, 
                    IdEvento, 
                    IdMetodoPago, 
                    Referencia ?? "", 
                    NumeroComprobante ?? ""
                );
                TempData["SuccessMessage"] = $"Factura #{newInvoiceId} emitida y registrada correctamente.";
                return RedirectToPage();
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = $"Error al emitir factura: {ex.Message}";
                Propietarios = await _propietarioRepo.ObtenerTodosAsync();
                Eventos = await _eventoRepo.ObtenerTodosAsync();
                return Page();
            }
        }

        public async Task<IActionResult> OnPostCalcularFrecuentesAsync()
        {
            try
            {
                await _facturacionRepo.EjecutarCalculoFrecuentesAsync();
                TempData["SuccessMessage"] = "Descuentos de propietarios frecuentes aplicados correctamente.";
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = $"Ocurrió un error al ejecutar el batch: {ex.Message}";
            }
            
            return RedirectToPage();
        }
    }
}
