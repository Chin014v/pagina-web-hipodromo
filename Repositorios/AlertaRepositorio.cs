using Dapper;
using System.Data;
using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public class AlertaRepositorio : IAlertaRepositorio
    {
        private readonly IDbConnection _db;

        public AlertaRepositorio(IDbConnection db)
        {
            _db = db;
        }

        public async Task<IEnumerable<AlertaCertificacionDTO>> ObtenerTodosAsync()
        {
            return await _db.QueryAsync<AlertaCertificacionDTO>(@"
                SELECT a.id_alerta AS IdAlerta, a.id_caballo AS IdCaballo,
                       a.mensaje AS Mensaje, a.estado AS Estado,
                       a.fecha_alerta AS FechaAlerta,
                       c.nombre AS NombreCaballo
                FROM alerta_certificacion a
                JOIN caballo c ON a.id_caballo = c.id_caballo
                ORDER BY a.fecha_alerta DESC");
        }

        public async Task<AlertaCertificacionDTO> ObtenerPorIdAsync(int id)
        {
            return await _db.QueryFirstOrDefaultAsync<AlertaCertificacionDTO>(@"
                SELECT a.id_alerta AS IdAlerta, a.id_caballo AS IdCaballo,
                       a.mensaje AS Mensaje, a.estado AS Estado,
                       a.fecha_alerta AS FechaAlerta,
                       c.nombre AS NombreCaballo
                FROM alerta_certificacion a
                JOIN caballo c ON a.id_caballo = c.id_caballo
                WHERE a.id_alerta = @Id", new { Id = id });
        }

        public async Task<bool> ActualizarAlertaAsync(int id, string estado, string mensaje, DateTime fechaAlerta)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id", id);
            parameters.Add("p_estado", estado);
            parameters.Add("p_mensaje", mensaje);
            parameters.Add("p_fecha_alerta", fechaAlerta);

            await _db.ExecuteAsync("sp_actualizar_alerta_certificacion", parameters, commandType: CommandType.StoredProcedure);
            return true;
        }

        public async Task<bool> EliminarAsync(int id)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id", id);

            await _db.ExecuteAsync("sp_eliminar_alerta_certificacion", parameters, commandType: CommandType.StoredProcedure);
            return true;
        }
    }
}