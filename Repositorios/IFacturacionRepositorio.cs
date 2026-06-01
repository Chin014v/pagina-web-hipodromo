using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public interface IFacturacionRepositorio
    {
        Task<bool> EjecutarCalculoFrecuentesAsync();
        Task<int> CrearFacturaAsync(int idPropietario, int idEvento, int? idMetodoPago, string referencia, string numeroComprobante);
        Task<FacturaDetalleDTO?> ObtenerFacturaDetalleAsync(int idFactura);
        Task<IEnumerable<FacturaDetalleDTO>> ObtenerTodasFacturasAsync(int? idPropietario = null);
    }
}
