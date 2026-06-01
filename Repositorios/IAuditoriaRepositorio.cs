using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public interface IAuditoriaRepositorio
    {
        Task<IEnumerable<AuditoriaDTO>> ObtenerPorTablaAsync(string nombreTabla);
        Task<IEnumerable<string>> ObtenerTablasConBitacoraAsync();
    }
}
