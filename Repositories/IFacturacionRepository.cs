namespace HipodromoNacional.Repositories
{
    public interface IFacturacionRepository
    {
        Task<bool> EjecutarCalculoFrecuentesAsync();
    }
}
