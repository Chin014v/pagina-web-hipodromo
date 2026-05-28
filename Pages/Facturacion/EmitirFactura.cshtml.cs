using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using System.Collections.Generic;
using System.Threading.Tasks;
using System;
using System.Data;
using Dapper;

namespace HipodromoNacional.Pages.Facturacion
{
    public class EmitirFacturaModel : PageModel
    {
        private readonly IFacturacionRepositorio _facturacionRepo;
        private readonly IPropietarioRepositorio _propietarioRepo;
        private readonly IEventoRepositorio _eventoRepo;
        private readonly IDbConnection _db;

        public EmitirFacturaModel(
            IFacturacionRepositorio facturacionRepo,
            IPropietarioRepositorio propietarioRepo,
            IEventoRepositorio eventoRepo,
            IDbConnection db)
        {
            _facturacionRepo = facturacionRepo;
            _propietarioRepo = propietarioRepo;
            _eventoRepo = eventoRepo;
            _db = db;
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

        public async Task<IActionResult> OnGetCalcularFrecuentesAsync()
        {
            try
            {
                await _facturacionRepo.EjecutarCalculoFrecuentesAsync();
                var list = await _propietarioRepo.ObtenerTodosAsync();
                return new JsonResult(new { success = true, propietarios = list });
            }
            catch (Exception ex)
            {
                return new JsonResult(new { success = false, message = ex.Message });
            }
        }

        public async Task<IActionResult> OnGetEventosPendientesAsync(int propietarioId)
        {
            try
            {
                var query = @"
                    SELECT DISTINCT e.id_evento AS id, e.nombre AS nombre, e.codigo_evento AS codigo, e.precio_inscripcion AS precio
                    FROM inscripcion i
                    JOIN caballo c ON i.id_caballo = c.id_caballo
                    JOIN evento e ON i.id_evento = e.id_evento
                    WHERE c.id_propietario = @PropietarioId
                      AND i.id_inscripcion NOT IN (SELECT id_inscripcion FROM detalle_factura)
                    ORDER BY e.nombre";
                
                var list = await _db.QueryAsync<dynamic>(query, new { PropietarioId = propietarioId });
                return new JsonResult(list);
            }
            catch (Exception ex)
            {
                return new JsonResult(new { error = ex.Message });
            }
        }
    }
}
