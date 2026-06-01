using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public interface IAlertaRepositorio
    {
        Task<IEnumerable<AlertaCertificacionDTO>> ObtenerTodosAsync();
        Task<AlertaCertificacionDTO> ObtenerPorIdAsync(int id);
        Task<bool> CrearAlertaAsync(int idCaballo, string mensaje);
        Task<bool> ActualizarAlertaAsync(int id, string estado, string mensaje, DateTime fechaAlerta);
        Task<bool> EliminarAsync(int id);
    }
}