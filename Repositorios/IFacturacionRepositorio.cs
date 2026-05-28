namespace HipodromoNacional.Repositorios
{
    public interface IFacturacionRepositorio
    {
        Task<bool> EjecutarCalculoFrecuentesAsync();
        Task<int> CrearFacturaAsync(int idPropietario, int idEvento, int? idMetodoPago, string referencia, string numeroComprobante);
    }
}
